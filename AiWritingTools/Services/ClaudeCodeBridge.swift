import Foundation
import os

final class ClaudeCodeBridge {
    enum BridgeError: Error, Equatable {
        case binaryNotFound
        case timeout
        case processFailed(String)
    }

    private let binaryPath: String
    private let timeout: TimeInterval
    private let logger = Logger(subsystem: "ai.amihuman.macos.AiWritingTools", category: "ClaudeCodeBridge")

    init(binaryPath: String? = nil, timeout: TimeInterval = 120) {
        self.binaryPath = binaryPath ?? Self.findBinary(named: "claude") ?? ""
        self.timeout = timeout
    }

    func run(prompt: String, systemPrompt: String? = nil) async throws -> String {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw BridgeError.binaryNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)

            if binaryPath.hasSuffix("claude") {
                var args = ["-p"]
                if let systemPrompt, !systemPrompt.isEmpty {
                    args += ["--system-prompt", systemPrompt]
                }
                process.arguments = args
            } else if !prompt.contains(" ") && !prompt.contains("\n") {
                // For non-claude binaries, pass single-token prompts as CLI arguments
                // so utilities like sleep receive their required positional argument.
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
                    resumeOnce(with: .success(output))
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

    static func findBinary(named name: String) -> String? {
        let knownPaths = [
            "/usr/local/bin/\(name)",
            "\(NSHomeDirectory())/.local/bin/\(name)",
            "\(NSHomeDirectory())/.claude/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]

        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "which \(name)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        } catch {
            return nil
        }

        return nil
    }
}
