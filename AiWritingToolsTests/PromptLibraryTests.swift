import XCTest
@testable import AiWritingTools

final class PromptLibraryTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AiWritingToolsTest-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testLoadCategoriesFromFolderStructure() {
        let cat = tempDir.appendingPathComponent("Correction")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        let prompt = "Fix spelling:\n\n{{text}}"
        try! prompt.write(to: cat.appendingPathComponent("Spelling.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, "Correction")
        XCTAssertEqual(categories[0].actions.count, 1)
        XCTAssertEqual(categories[0].actions[0].name, "Spelling")
        XCTAssertEqual(categories[0].actions[0].template, prompt)
    }

    func testIgnoresEmptyFiles() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        try! "".write(to: cat.appendingPathComponent("Empty.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        // Category with only invalid files is filtered out
        XCTAssertTrue(categories.isEmpty)
    }

    func testIgnoresFilesWithoutPlaceholder() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        try! "No placeholder".write(to: cat.appendingPathComponent("Bad.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        // Category with only invalid files is filtered out
        XCTAssertTrue(categories.isEmpty)
    }

    func testIgnoresNonMdFiles() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        try! "{{text}}".write(to: cat.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        // Category with only non-.md files is filtered out
        XCTAssertTrue(categories.isEmpty)
    }

    func testMultipleCategoriesSortedAlphabetically() {
        for name in ["Style", "Correction", "Translation"] {
            let cat = tempDir.appendingPathComponent(name)
            try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
            try! "Do: {{text}}".write(to: cat.appendingPathComponent("Action.md"), atomically: true, encoding: .utf8)
        }

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.map(\.name), ["Correction", "Style", "Translation"])
    }

    func testEmptyDirectoryReturnsNoCategories() {
        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()
        XCTAssertTrue(categories.isEmpty)
    }

    func testLoadSystemPrompt() {
        let content = "Je bent een assistent. Geef alleen het resultaat."
        try! content.write(to: tempDir.appendingPathComponent("_system.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        XCTAssertEqual(library.loadSystemPrompt(), content)
    }

    func testLoadSystemPromptReturnsNilWhenMissing() {
        let library = PromptLibrary(directory: tempDir)
        XCTAssertNil(library.loadSystemPrompt())
    }

    func testLoadSystemPromptReturnsNilWhenEmpty() {
        try! "  \n  ".write(to: tempDir.appendingPathComponent("_system.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        XCTAssertNil(library.loadSystemPrompt())
    }

    func testLoadCategoriesWithImageContent() {
        let cat = tempDir.appendingPathComponent("Image")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        try! "Describe: {{image}}".write(to: cat.appendingPathComponent("Describe.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)

        let textOnly = library.loadCategories(availableContent: [.text])
        XCTAssertTrue(textOnly.isEmpty)

        let withImage = library.loadCategories(availableContent: [.image])
        XCTAssertEqual(withImage.count, 1)
        XCTAssertEqual(withImage[0].actions[0].name, "Describe")
    }

    func testLoadCategoriesMixedContentFiltering() {
        let textCat = tempDir.appendingPathComponent("Correction")
        try! FileManager.default.createDirectory(at: textCat, withIntermediateDirectories: true)
        try! "Fix: {{text}}".write(to: textCat.appendingPathComponent("Spelling.md"), atomically: true, encoding: .utf8)

        let imgCat = tempDir.appendingPathComponent("Image")
        try! FileManager.default.createDirectory(at: imgCat, withIntermediateDirectories: true)
        try! "Describe: {{image}}".write(to: imgCat.appendingPathComponent("OCR.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)

        let textOnly = library.loadCategories(availableContent: [.text])
        XCTAssertEqual(textOnly.count, 1)
        XCTAssertEqual(textOnly[0].name, "Correction")

        let both = library.loadCategories(availableContent: [.text, .image])
        XCTAssertEqual(both.count, 2)
    }

    func testAcceptsImagePlaceholderInValidation() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        try! "Describe: {{image}}".write(to: cat.appendingPathComponent("Img.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories(availableContent: [.image])
        XCTAssertEqual(categories.count, 1)
    }

    func testRejectsPromptsWithoutAnyPlaceholder() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        try! "No placeholder at all".write(to: cat.appendingPathComponent("Bad.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories(availableContent: [.text, .image])
        XCTAssertTrue(categories.isEmpty)
    }

    func testLoadActionWithFrontmatterModel() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        let content = "---\nmodel: haiku\n---\nFix: {{text}}"
        try! content.write(to: cat.appendingPathComponent("Fix.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].actions[0].model, "haiku")
        XCTAssertEqual(categories[0].actions[0].template, "Fix: {{text}}")
    }

    func testLoadActionWithoutFrontmatterHasNilModel() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        try! "Fix: {{text}}".write(to: cat.appendingPathComponent("Fix.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.count, 1)
        XCTAssertNil(categories[0].actions[0].model)
    }

    func testLoadActionWithEmptyFrontmatter() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        let content = "---\n---\nFix: {{text}}"
        try! content.write(to: cat.appendingPathComponent("Fix.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.count, 1)
        XCTAssertNil(categories[0].actions[0].model)
        XCTAssertEqual(categories[0].actions[0].template, "Fix: {{text}}")
    }

    func testLoadActionWithModelWhitespace() {
        let cat = tempDir.appendingPathComponent("Test")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        let content = "---\nmodel:  sonnet  \n---\nFix: {{text}}"
        try! content.write(to: cat.appendingPathComponent("Fix.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories[0].actions[0].model, "sonnet")
    }
}
