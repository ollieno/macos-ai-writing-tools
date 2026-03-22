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

        // IMPORTANT: extract image BEFORE getSelectedText,
        // because Cmd+C fallback in TextAccessor overwrites the clipboard
        let imagePath = ClipboardInspector.extractImage()
        let selectedText = TextAccessor.getSelectedText()
        let hasText = selectedText != nil && !selectedText!.isEmpty

        guard hasText || imagePath != nil else { return }

        let content = ClipboardContent(
            text: hasText ? selectedText : nil,
            imagePath: imagePath
        )

        let library = PromptLibrary()
        let categories = library.loadCategories(availableContent: content.availableContentTypes)
        let systemPrompt = library.loadSystemPrompt()

        guard !categories.isEmpty else {
            if let imagePath { ClipboardInspector.cleanup(path: imagePath) }
            return
        }

        popup.show(
            content: content,
            categories: categories,
            onAction: { [weak self] prompt in
                guard let self else { return nil }
                do {
                    return try await self.bridge.run(prompt: prompt, systemPrompt: systemPrompt)
                } catch let bridgeError as ClaudeCodeBridge.BridgeError {
                    await MainActor.run {
                        self.showError(bridgeError)
                    }
                    return nil
                } catch {
                    return nil
                }
            },
            onReplace: { result in
                if let imagePath { ClipboardInspector.cleanup(path: imagePath) }
                sourceApp?.activate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    TextAccessor.pasteText(result)
                }
            },
            onCopy: { result in
                if let imagePath { ClipboardInspector.cleanup(path: imagePath) }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
                sourceApp?.activate()
            },
            onCancel: {
                if let imagePath { ClipboardInspector.cleanup(path: imagePath) }
                sourceApp?.activate()
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
        alert.messageText = "AI Writing Tools"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
