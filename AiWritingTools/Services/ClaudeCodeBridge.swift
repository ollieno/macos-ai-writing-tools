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
    private static var sandboxDirectory: URL {
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
    }

    /// Ensures `<isolated-home>/.claude/.credentials.json` resolves to a usable
    /// credentials file. The isolated HOME always symlinks to the real
    /// `~/.claude/.credentials.json`, so Claude CLI token refreshes persist to
    /// the canonical location shared with the host CLI.
    ///
    /// If the real file does not yet exist (fresh installs where Claude Code
    /// stores OAuth tokens only in the macOS Keychain), seed it once by
    /// extracting the `Claude Code-credentials` Keychain entry and writing it
    /// to `~/.claude/.credentials.json`. After that initial seed the Keychain
    /// is no longer consulted: Claude CLI refresh cycles update the file
    /// directly, keeping AI Writing Tools and the host CLI in sync.
    private static func ensureCredentials(in claudeDir: URL) throws {
        let fm = FileManager.default
        let credentialsURL = claudeDir.appendingPathComponent(".credentials.json")
        let realCredentials = realCredentialsURL

        if !fm.fileExists(atPath: realCredentials.path) {
            if let keychainData = readCredentialsFromKeychain() {
                try seedRealCredentials(keychainData, to: realCredentials)
            }
        }

        if fm.fileExists(atPath: realCredentials.path) {
            try symlinkCredentials(at: credentialsURL, to: realCredentials)
        }
    }

    /// Writes the initial credentials file into the real `~/.claude/` directory.
    /// Creates the parent if missing and locks the file to 0600 to match Claude
    /// CLI's own permission model.
    private static func seedRealCredentials(_ data: Data, to url: URL) throws {
        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
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

    /// Reads OAuth credentials JSON from the `Claude Code-credentials` Keychain
    /// entry. Returns nil if the entry is missing or `security` fails (e.g. the
    /// user denies access). Equivalent to:
    ///     security find-generic-password -s "Claude Code-credentials" -w
    private static func readCredentialsFromKeychain() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return trimmed.data(using: .utf8)
        } catch {
            return nil
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
        return [
            "HOME": isolatedHome,
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
