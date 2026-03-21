import AppKit
import UserNotifications

class ServiceProvider: NSObject {
    private let popup = PopupWindow()
    private let bridge = ClaudeCodeBridge()

    @objc func processText(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pboard.string(forType: .string) else { return }

        let library = PromptLibrary()
        let categories = library.loadCategories()

        let sourceApp = NSWorkspace.shared.frontmostApplication

        popup.show(
            text: text,
            categories: categories,
            onAction: { [weak self] prompt in
                guard let self else { return nil }
                do {
                    return try await self.bridge.run(prompt: prompt)
                } catch let bridgeError as ClaudeCodeBridge.BridgeError {
                    await MainActor.run {
                        self.showError(bridgeError)
                    }
                    return nil
                } catch {
                    return nil
                }
            },
            onComplete: { [weak self] result in
                self?.popup.dismiss()

                if let result {
                    pboard.clearContents()
                    let written = pboard.setString(result, forType: .string)

                    if !written {
                        let systemPboard = NSPasteboard.general
                        systemPboard.clearContents()
                        systemPboard.setString(result, forType: .string)
                        self?.sendNotification("Resultaat gekopieerd naar klembord")
                    }
                }

                sourceApp?.activate()
            }
        )
    }

    private func sendNotification(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "AiTools"
        content.body = message
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func showError(_ error: ClaudeCodeBridge.BridgeError) {
        let message: String
        switch error {
        case .binaryNotFound:
            message = "Claude CLI niet gevonden. Installeer Claude Code via: npm install -g @anthropic-ai/claude-code"
        case .timeout:
            message = "Verwerking duurde te lang (timeout). Probeer het opnieuw."
        case .processFailed(let detail):
            message = "Fout bij verwerking: \(detail)"
        }

        let alert = NSAlert()
        alert.messageText = "AiTools"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
