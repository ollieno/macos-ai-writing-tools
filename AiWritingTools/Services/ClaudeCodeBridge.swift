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
        try linkCredentials(into: claudeDir)
    }

    /// Symlinks `<isolated-home>/.claude/.credentials.json` to the user's real
    /// credentials so OAuth login is shared with the user's terminal Claude CLI
    /// and token refreshes write back to the canonical location.
    private static func linkCredentials(into claudeDir: URL) throws {
        let fm = FileManager.default
        let realCredentials = realCredentialsURL

        guard fm.fileExists(atPath: realCredentials.path) else { return }

        let linkURL = claudeDir.appendingPathComponent(".credentials.json")
        let linkPath = linkURL.path
        let existingTarget = try? fm.destinationOfSymbolicLink(atPath: linkPath)

        if existingTarget == realCredentials.path { return }

        if existingTarget != nil || fm.fileExists(atPath: linkPath) {
            try fm.removeItem(at: linkURL)
        }

        try fm.createSymbolicLink(at: linkURL, withDestinationURL: realCredentials)
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
                    let errOutput = String(data: errData, encoding: .utf8) ?? "Unknown error"
                    resumeOnce(with: .failure(BridgeError.processFailed(errOutput)))
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
