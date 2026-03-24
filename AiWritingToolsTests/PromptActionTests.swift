import XCTest
@testable import AiWritingTools

final class PromptActionTests: XCTestCase {
    func testComposePromptReplacesPlaceholder() {
        let action = PromptAction(
            name: "Test",
            template: "Fix this:\n\n{{text}}"
        )
        let result = action.composePrompt(text: "Hello wrold", imagePath: nil)
        XCTAssertEqual(result, "Fix this:\n\nHello wrold")
    }

    func testComposePromptWithoutPlaceholderReturnsTemplate() {
        let action = PromptAction(
            name: "Bad",
            template: "No placeholder here"
        )
        XCTAssertEqual(action.composePrompt(text: "text", imagePath: nil), "No placeholder here")
    }

    func testComposePromptMultiplePlaceholders() {
        let action = PromptAction(
            name: "Multi",
            template: "A: {{text}} B: {{text}}"
        )
        let result = action.composePrompt(text: "hi", imagePath: nil)
        XCTAssertEqual(result, "A: hi B: hi")
    }

    func testFreeformPromptComposition() {
        let result = PromptAction.composeFreeformPrompt(
            instruction: "Make it funny",
            text: "Hello world",
            imagePath: nil
        )
        XCTAssertEqual(result, "Make it funny\n\nReturn only the result, without explanation.\n\nHello world")
    }

    // MARK: - ContentType and image placeholder tests

    func testRequiredContentTypesTextOnly() {
        let action = PromptAction(name: "T", template: "Fix: {{text}}")
        XCTAssertEqual(action.requiredContentTypes, [.text])
    }

    func testRequiredContentTypesImageOnly() {
        let action = PromptAction(name: "T", template: "Describe: {{image}}")
        XCTAssertEqual(action.requiredContentTypes, [.image])
    }

    func testRequiredContentTypesBoth() {
        let action = PromptAction(name: "T", template: "Context: {{text}} Image: {{image}}")
        XCTAssertEqual(action.requiredContentTypes, [.text, .image])
    }

    func testComposePromptWithImage() {
        let action = PromptAction(name: "T", template: "Describe: {{image}}")
        let result = action.composePrompt(text: nil, imagePath: "/tmp/test.png")
        XCTAssertEqual(result, "Describe: /tmp/test.png")
    }

    func testComposePromptWithTextAndImage() {
        let action = PromptAction(name: "T", template: "Context: {{text}} Image: {{image}}")
        let result = action.composePrompt(text: "hello", imagePath: "/tmp/test.png")
        XCTAssertEqual(result, "Context: hello Image: /tmp/test.png")
    }

    func testComposePromptReturnsNilWhenImageMissing() {
        let action = PromptAction(name: "T", template: "Describe: {{image}}")
        let result = action.composePrompt(text: "hello", imagePath: nil)
        XCTAssertNil(result)
    }

    func testComposePromptReturnsNilWhenTextMissing() {
        let action = PromptAction(name: "T", template: "Fix: {{text}}")
        let result = action.composePrompt(text: nil, imagePath: "/tmp/test.png")
        XCTAssertNil(result)
    }

    func testFreeformWithImage() {
        let result = PromptAction.composeFreeformPrompt(
            instruction: "Describe this",
            text: nil,
            imagePath: "/tmp/test.png"
        )
        XCTAssertTrue(result.contains("/tmp/test.png"))
        XCTAssertTrue(result.contains("Describe this"))
    }

    func testFreeformWithTextAndImage() {
        let result = PromptAction.composeFreeformPrompt(
            instruction: "Translate",
            text: "context here",
            imagePath: "/tmp/test.png"
        )
        XCTAssertTrue(result.contains("context here"))
        XCTAssertTrue(result.contains("/tmp/test.png"))
        XCTAssertTrue(result.contains("Translate"))
    }

    // MARK: - Model property tests

    func testModelPropertyIsStored() {
        let action = PromptAction(name: "Test", template: "{{text}}", model: "haiku")
        XCTAssertEqual(action.model, "haiku")
    }

    func testModelDefaultsToNil() {
        let action = PromptAction(name: "Test", template: "{{text}}")
        XCTAssertNil(action.model)
    }
}
