import AppKit

struct ClipboardContent {
    let text: String?
    let imagePath: String?

    var availableContentTypes: Set<ContentType> {
        var types = Set<ContentType>()
        if let text, !text.isEmpty { types.insert(.text) }
        if imagePath != nil { types.insert(.image) }
        return types
    }

    var hasText: Bool { text != nil && !text!.isEmpty }
    var hasImage: Bool { imagePath != nil }
}

struct ClipboardInspector {
    static func extractImage() -> String? {
        let pasteboard = NSPasteboard.general
        guard let image = NSImage(pasteboard: pasteboard) else { return nil }
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let path = NSTemporaryDirectory() + "aiwritingtools-\(UUID().uuidString).png"
        do {
            try pngData.write(to: URL(fileURLWithPath: path))
            return path
        } catch {
            return nil
        }
    }

    static func cleanup(path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
