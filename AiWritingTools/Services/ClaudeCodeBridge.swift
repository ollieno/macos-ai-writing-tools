import Foundation
import os

final class ClaudeCodeBridge {
    enum BridgeError: Error, Equatable {
        case binaryNotFound
        case timeout
        case processFailed(String)
    }

    private let overridePath: String?
    private let timeout: TimeInterval
    private let logger = Logger(subsystem: "ai.amihuman.macos.AiWritingTools", category: "ClaudeCodeBridge")

    private static let knownPaths = [
        "/usr/local/bin/claude",
        "\(NSHomeDirectory())/.local/bin/claude",
        "\(NSHomeDirectory())/.claude/bin/claude",
        "/opt/homebrew/bin/claude",
        "/usr/bin/claude",
        "/bin/claude"
    ]

    init(binaryPath: String? = nil, timeout: TimeInterval = 120) {
        self.overridePath = binaryPath
        self.timeout = timeout
    }

    func run(prompt: String, systemPrompt: String? = nil) async throws -> String {
        if let overridePath {
            return try await execute(binaryPath: overridePath, prompt: prompt, systemPrompt: systemPrompt)
        }

        for path in Self.knownPaths {
            guard FileManager.default.isExecutableFile(atPath: path) else { continue }
            return try await execute(binaryPath: path, prompt: prompt, systemPrompt: systemPrompt)
        }

        throw BridgeError.binaryNotFound
    }

    private func execute(binaryPath: String, prompt: String, systemPrompt: String?) async throws -> String {
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
}
