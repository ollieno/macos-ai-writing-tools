import AppKit

final class TextProcessor {
    private let popup = PopupWindow()
    private let bridge = ClaudeCodeBridge()

    func processSelectedText() {
        guard TextAccessor.isAccessibilityGranted() else {
            _ = TextAccessor.ensureAccessibilityPermission()
            return
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication

        guard let selectedText = TextAccessor.getSelectedText(), !selectedText.isEmpty else {
            return
        }

        let library = PromptLibrary()
        let categories = library.loadCategories()

        popup.show(
            text: selectedText,
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
                    sourceApp?.activate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        TextAccessor.pasteText(result)
                    }
                } else {
                    sourceApp?.activate()
                }
            }
        )
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
