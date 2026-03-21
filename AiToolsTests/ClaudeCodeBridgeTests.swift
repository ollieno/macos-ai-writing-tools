import XCTest
@testable import AiTools

final class ClaudeCodeBridgeTests: XCTestCase {
    func testFindClaudeBinaryReturnsPathWhenEchoExists() {
        let path = ClaudeCodeBridge.findBinary(named: "echo")
        XCTAssertNotNil(path)
    }

    func testFindClaudeBinaryReturnsNilForNonexistent() {
        let path = ClaudeCodeBridge.findBinary(named: "definitely-not-a-real-binary-xyz")
        XCTAssertNil(path)
    }

    func testRunProcessCapturesStdoutViaStdin() async throws {
        let bridge = ClaudeCodeBridge(binaryPath: "/bin/cat")
        let result = try await bridge.run(prompt: "hello world")
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
}
