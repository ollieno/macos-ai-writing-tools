import XCTest
@testable import AiTools

final class PromptActionTests: XCTestCase {
    func testComposePromptReplacesPlaceholder() {
        let action = PromptAction(
            name: "Test",
            template: "Fix this:\n\n{{text}}"
        )
        let result = action.composePrompt(with: "Hello wrold")
        XCTAssertEqual(result, "Fix this:\n\nHello wrold")
    }

    func testComposePromptWithoutPlaceholderReturnsNil() {
        let action = PromptAction(
            name: "Bad",
            template: "No placeholder here"
        )
        XCTAssertNil(action.composePrompt(with: "text"))
    }

    func testComposePromptMultiplePlaceholders() {
        let action = PromptAction(
            name: "Multi",
            template: "A: {{text}} B: {{text}}"
        )
        let result = action.composePrompt(with: "hi")
        XCTAssertEqual(result, "A: hi B: hi")
    }

    func testFreeformPromptComposition() {
        let result = PromptAction.composeFreeformPrompt(
            instruction: "Make it funny",
            text: "Hello world"
        )
        XCTAssertEqual(result, "Make it funny\n\nHello world")
    }
}
