import ApplicationServices
import AppKit

struct TextAccessor {
    static func ensureAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    static func getSelectedText() -> String? {
        // Try AX first
        if let text = getSelectedTextViaAX() {
            return text
        }
        // Fallback: Cmd+C
        return getSelectedTextViaCopy()
    }

    private static func getSelectedTextViaAX() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success,
              let element = focusedElement else {
            return nil
        }

        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        guard textResult == .success,
              let text = selectedText as? String,
              !text.isEmpty else {
            return nil
        }

        return text
    }

    private static func getSelectedTextViaCopy() -> String? {
        let pasteboard = NSPasteboard.general
        let oldChangeCount = pasteboard.changeCount

        // Simulate Cmd+C
        simulateKeyPress(keyCode: 8, flags: .maskCommand) // 8 = C key
        usleep(100_000) // 100ms for clipboard to update

        // Check if clipboard changed
        guard pasteboard.changeCount != oldChangeCount else {
            return nil
        }

        return pasteboard.string(forType: .string)
    }

    static func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure pasteboard is ready
        usleep(50_000)

        // Simulate Cmd+V
        simulateKeyPress(keyCode: 9, flags: .maskCommand) // 9 = V key
    }

    private static func simulateKeyPress(keyCode: UInt16, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
