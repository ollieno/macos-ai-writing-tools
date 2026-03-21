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
        let cat = tempDir.appendingPathComponent("Correctie")
        try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
        let prompt = "Fix spelling:\n\n{{text}}"
        try! prompt.write(to: cat.appendingPathComponent("Spelling.md"), atomically: true, encoding: .utf8)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].name, "Correctie")
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
        for name in ["Stijl", "Correctie", "Vertaling"] {
            let cat = tempDir.appendingPathComponent(name)
            try! FileManager.default.createDirectory(at: cat, withIntermediateDirectories: true)
            try! "Do: {{text}}".write(to: cat.appendingPathComponent("Action.md"), atomically: true, encoding: .utf8)
        }

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.map(\.name), ["Correctie", "Stijl", "Vertaling"])
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
}
