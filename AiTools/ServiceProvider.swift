import AppKit

class ServiceProvider: NSObject {
    @objc func processText(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pboard.string(forType: .string) else { return }
        // Implemented in Task 7
    }
}
