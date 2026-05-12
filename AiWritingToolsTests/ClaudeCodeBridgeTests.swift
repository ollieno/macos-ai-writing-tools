import XCTest
@testable import AiWritingTools

final class ClaudeCodeBridgeTests: XCTestCase {
    func testRunProcessCapturesStdoutViaStdin() async throws {
        let bridge = ClaudeCodeBridge(binaryPath: "/bin/cat")
        let result = try await bridge.run(prompt: "hello world")
        XCTAssertEqual(result, "hello world")
    }

    func testRunAcceptsModelParameter() async throws {
        let bridge = ClaudeCodeBridge(binaryPath: "/bin/cat")
        let result = try await bridge.run(prompt: "hello world", model: "haiku")
        XCTAssertEqual(result, "hello world")
    }

    func testRunProcessTimesOut() async {
        let bridge = ClaudeCodeBridge(binaryPath: "/bin/sleep", timeout: 1)
        do {
            _ = try await bridge.run(prompt: "10")
            XCTFail("Expected timeout error")
        } catch let error as ClaudeCodeBridge.BridgeError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProcessFailedFallsBackToStdoutWhenStderrEmpty() async throws {
        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aiwt-bridge-test-\(UUID().uuidString).sh")
        try "#!/bin/sh\ncat > /dev/null\necho 'Not logged in'\nexit 1\n"
            .write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let bridge = ClaudeCodeBridge(binaryPath: scriptURL.path)
        do {
            _ = try await bridge.run(prompt: "test prompt")
            XCTFail("Expected processFailed")
        } catch ClaudeCodeBridge.BridgeError.processFailed(let detail) {
            XCTAssertEqual(detail, "Not logged in")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
