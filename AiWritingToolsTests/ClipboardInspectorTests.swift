import XCTest
@testable import AiWritingTools

final class ClipboardInspectorTests: XCTestCase {
    func testExtractImageReturnsNilWhenNoImage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("just text", forType: .string)

        let path = ClipboardInspector.extractImage()
        XCTAssertNil(path)
    }

    func testExtractImageReturnsPngPath() {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])

        let path = ClipboardInspector.extractImage()
        XCTAssertNotNil(path)
        XCTAssertTrue(path!.hasSuffix(".png"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path!))

        if let path { ClipboardInspector.cleanup(path: path) }
    }

    func testCleanupRemovesTempFile() {
        let tempPath = NSTemporaryDirectory() + "aiwritingtools-test-\(UUID().uuidString).png"
        FileManager.default.createFile(atPath: tempPath, contents: Data([0x89, 0x50]))

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempPath))
        ClipboardInspector.cleanup(path: tempPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempPath))
    }

    func testCleanupHandlesMissingFile() {
        ClipboardInspector.cleanup(path: "/tmp/nonexistent-file.png")
    }

    func testExtractImageUsesUniquePaths() {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.blue.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])

        let path1 = ClipboardInspector.extractImage()
        let path2 = ClipboardInspector.extractImage()

        XCTAssertNotNil(path1)
        XCTAssertNotNil(path2)
        XCTAssertNotEqual(path1, path2)

        if let path1 { ClipboardInspector.cleanup(path: path1) }
        if let path2 { ClipboardInspector.cleanup(path: path2) }
    }
}
