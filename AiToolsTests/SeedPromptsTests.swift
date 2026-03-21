import XCTest
@testable import AiTools

final class SeedPromptsTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AiToolsSeed-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSeedCreatesDirectoryAndPrompts() throws {
        try SeedPrompts.installIfNeeded(to: tempDir)

        let library = PromptLibrary(directory: tempDir)
        let categories = library.loadCategories()

        XCTAssertEqual(categories.count, 3)

        let allActions = categories.flatMap(\.actions)
        XCTAssertEqual(allActions.count, 7)
    }

    func testSeedDoesNotOverwriteExisting() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let marker = tempDir.appendingPathComponent("marker.txt")
        try "exists".write(to: marker, atomically: true, encoding: .utf8)

        try SeedPrompts.installIfNeeded(to: tempDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
    }
}
