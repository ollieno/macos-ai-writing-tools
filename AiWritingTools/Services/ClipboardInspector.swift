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
        let types = pasteboard.types ?? []

        // Only read raw image data (TIFF/PNG) directly from the pasteboard.
        // Avoid NSImage(pasteboard:) as it resolves file URLs, which triggers
        // macOS TCC permission dialogs when the image came from Photos or
        // other protected locations.
        let rawImageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        guard let matchedType = rawImageTypes.first(where: { types.contains($0) }),
              let data = pasteboard.data(forType: matchedType),
              let image = NSImage(data: data) else {
            return nil
        }

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
