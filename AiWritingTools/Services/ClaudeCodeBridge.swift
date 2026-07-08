import Foundation
import os

final class ClaudeCodeBridge {
    enum BridgeError: Error, Equatable {
        case binaryNotFound
        case timeout
        case processFailed(String)
    }

    static var pluginDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AiWritingTools/plugin")
    }

    /// Empty sandbox directory so Claude CLI does not scan the host app's working directory.
    /// Also the read scope for the CLI: files here (e.g. a pasted image) are inside the
    /// subprocess cwd, so the Read tool allows them without an interactive permission prompt.
    static var sandboxDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AiWritingTools/sandbox")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Isolated HOME for the Claude subprocess. Prevents Claude CLI from reading
    /// the user's real ~/.claude/projects/ directory, which often contains paths
    /// pointing into Google Drive / iCloud / Music libraries and triggers macOS
    /// per-app TCC prompts attributed to AI Writing Tools.
    private static var isolatedHomeDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AiWritingTools/claude-home")
    }

    /// Path to the real user's Claude credentials file (OAuth tokens).
    /// We do not move or copy this; we link to it from the isolated HOME so that
    /// token refreshes write back to the canonical location.
    private static var realCredentialsURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/.credentials.json")
    }

    /// Prepares the isolated HOME directory structure for the Claude subprocess.
    /// Creates `<isolated-home>/.claude/` and ensures credentials are reachable.
    /// Safe to call repeatedly; idempotent.
    private static func prepareIsolatedHome() throws {
        let fm = FileManager.default
        let claudeDir = isolatedHomeDirectory.appendingPathComponent(".claude")
        try fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        try ensureCredentials(in: claudeDir)
        try ensureKeychainAccess()
    }

    /// Symlinks `<isolated-home>/Library/Keychains` to the real
    /// `~/Library/Keychains`. Claude CLI stores and refreshes its OAuth tokens in
    /// the macOS login Keychain, whose location the Security framework resolves
    /// from `$HOME`. Without this link the isolated HOME has no Keychains
    /// directory, so a token refresh write fails with the system dialog
    /// "A keychain cannot be found to store". Sharing the directory lets refreshes
    /// land in the real login Keychain, in sync with the host CLI.
    private static func ensureKeychainAccess() throws {
        let fm = FileManager.default
        let realKeychains = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Keychains")
        guard fm.fileExists(atPath: realKeychains.path) else { return }

        let isolatedLibrary = isolatedHomeDirectory.appendingPathComponent("Library")
        try fm.createDirectory(at: isolatedLibrary, withIntermediateDirectories: true)
        let linkURL = isolatedLibrary.appendingPathComponent("Keychains")

        if (try? fm.destinationOfSymbolicLink(atPath: linkURL.path)) == realKeychains.path {
            return
        }
        if fm.fileExists(atPath: linkURL.path) || (try? fm.destinationOfSymbolicLink(atPath: linkURL.path)) != nil {
            try fm.removeItem(at: linkURL)
        }
        try fm.createSymbolicLink(at: linkURL, withDestinationURL: realKeychains)
    }

    /// Ensures the Claude CLI in the isolated HOME can find OAuth credentials.
    ///
    /// The login Keychain is shared into the isolated HOME (see
    /// `ensureKeychainAccess`), so on macOS the CLI uses it as its single source
    /// of truth, exactly like the host CLI. We must NOT shadow it with a symlink
    /// to `~/.claude/.credentials.json`: the host refreshes tokens in the
    /// Keychain and never rewrites that file, so a linked copy goes stale and the
    /// CLI reports "Not logged in". Only fall back to the file when the Keychain
    /// has no entry (rare file-only setups); otherwise drop any stale link.
    private static func ensureCredentials(in claudeDir: URL) throws {
        let fm = FileManager.default
        let credentialsURL = claudeDir.appendingPathComponent(".credentials.json")

        if keychainHasCredentials() {
            removeCredentialsLink(at: credentialsURL)
            return
        }

        let realCredentials = realCredentialsURL
        if fm.fileExists(atPath: realCredentials.path) {
            try symlinkCredentials(at: credentialsURL, to: realCredentials)
        }
    }

    /// Removes a previously created `.credentials.json` symlink (or file) from the
    /// isolated HOME so it cannot shadow the shared Keychain. No-op if absent.
    private static func removeCredentialsLink(at url: URL) {
        let fm = FileManager.default
        if (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil || fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: url)
        }
    }

    private static func symlinkCredentials(at linkURL: URL, to target: URL) throws {
        let fm = FileManager.default
        let linkPath = linkURL.path
        let existingTarget = try? fm.destinationOfSymbolicLink(atPath: linkPath)

        if existingTarget == target.path { return }

        if existingTarget != nil || fm.fileExists(atPath: linkPath) {
            try fm.removeItem(at: linkURL)
        }
        try fm.createSymbolicLink(at: linkURL, withDestinationURL: target)
    }

    /// Returns true if the `Claude Code-credentials` entry exists in the login
    /// Keychain. Presence check only (no `-w`), so it never extracts the secret:
    ///     security find-generic-password -s "Claude Code-credentials"
    private static func keychainHasCredentials() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private let overridePath: String?
    private let timeout: TimeInterval
    private let logger = Logger(subsystem: "ai.amihuman.macos.AiWritingTools", category: "ClaudeCodeBridge")

    init(binaryPath: String? = nil, timeout: TimeInterval = 120) {
        self.overridePath = binaryPath
        self.timeout = timeout
    }

    func run(prompt: String, systemPrompt: String? = nil, model: String? = nil) async throws -> String {
        let path = try resolveBinaryPath()
        try Self.prepareIsolatedHome()
        return try await execute(binaryPath: path, prompt: prompt, systemPrompt: systemPrompt, model: model)
    }

    func version() throws -> String {
        let path = try resolveBinaryPath()
        try Self.prepareIsolatedHome()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.currentDirectoryURL = Self.sandboxDirectory
        process.environment = Self.minimalEnvironment()
        process.arguments = ["-v"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let knownPaths = [
        "\(NSHomeDirectory())/.local/bin/claude",
        "/usr/local/bin/claude",
        "\(NSHomeDirectory())/.claude/bin/claude",
        "/opt/homebrew/bin/claude"
    ]

    private func resolveBinaryPath() throws -> String {
        if let overridePath {
            return overridePath
        }
        if let path = Self.knownPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return path
        }
        throw BridgeError.binaryNotFound
    }

    private static func minimalEnvironment() -> [String: String] {
        let realHome = NSHomeDirectory()
        let isolatedHome = isolatedHomeDirectory.path
        // USER/LOGNAME are required for macOS Keychain access: without the user
        // identity the Security framework cannot unlock the login Keychain, so
        // Claude CLI cannot read its OAuth token and reports "Not logged in".
        let userName = NSUserName()
        return [
            "HOME": isolatedHome,
            "USER": userName,
            "LOGNAME": userName,
            "PATH": "\(realHome)/.local/bin:/usr/local/bin:\(realHome)/.claude/bin:/opt/homebrew/bin:/usr/bin:/bin",
            "LANG": ProcessInfo.processInfo.environment["LANG"] ?? "en_US.UTF-8",
            "TERM": "dumb"
        ]
    }

    private func execute(binaryPath: String, prompt: String, systemPrompt: String?, model: String?) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.currentDirectoryURL = Self.sandboxDirectory
            process.environment = Self.minimalEnvironment()

            if binaryPath.hasSuffix("claude") {
                var args = ["-p", "--tools", "Read", "--disable-slash-commands"]
                if let systemPrompt, !systemPrompt.isEmpty {
                    args += ["--system-prompt", systemPrompt]
                }
                let pluginDir = Self.pluginDirectory
                if FileManager.default.fileExists(atPath: pluginDir.appendingPathComponent("plugin.json").path) {
                    args += ["--plugin-dir", pluginDir.path]
                }
                if let model, !model.isEmpty {
                    args += ["--model", model]
                }
                process.arguments = args
            } else if !prompt.contains(" ") && !prompt.contains("\n") {
                process.arguments = [prompt]
            }

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            var didResume = false
            let lock = NSLock()
            func resumeOnce(with result: Result<String, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                process.terminate()
                resumeOnce(with: .failure(BridgeError.timeout))
            }
            timer.resume()

            process.terminationHandler = { _ in
                timer.cancel()
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    resumeOnce(with: .success(output.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errOutput = String(data: errData, encoding: .utf8) ?? ""
                    let stderrTrimmed = errOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    let stdoutTrimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Claude CLI writes some failure messages (e.g. "Not logged in") to stdout,
                    // so fall back to stdout when stderr is empty.
                    let detail = stderrTrimmed.isEmpty ? stdoutTrimmed : stderrTrimmed
                    resumeOnce(with: .failure(BridgeError.processFailed(detail.isEmpty ? "Unknown error" : detail)))
                }
            }

            do {
                try process.run()
                let inputData = prompt.data(using: .utf8) ?? Data()
                stdinPipe.fileHandleForWriting.write(inputData)
                stdinPipe.fileHandleForWriting.closeFile()
            } catch {
                timer.cancel()
                resumeOnce(with: .failure(error))
            }
        }
    }
}
