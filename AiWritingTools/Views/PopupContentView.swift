import AppKit
import SwiftUI

private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DragView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct SubmitTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = SubmitTextView()
        textView.delegate = context.coordinator
        textView.submitHandler = onSubmit
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }

    private class SubmitTextView: NSTextView {
        var submitHandler: (() -> Void)?

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
                submitHandler?()
                return
            }
            super.keyDown(with: event)
        }
    }
}

struct PopupContentView: View {
    let categories: [PromptCategory]
    let content: ClipboardContent
    let onAction: (String, String?) async -> String?
    let onReplace: (String) -> Void
    let onCopy: (String) -> Void
    let onDismiss: () -> Void

    @State private var freeformText = ""
    @State private var state: ProcessingState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AI Writing Tools")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(WindowDragArea())

            // Content indicators
            HStack(spacing: 8) {
                if content.hasText {
                    Label("Tekst", systemImage: "doc.text")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                if content.hasImage {
                    Label("Image", systemImage: "photo")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            switch state {
            case .idle:
                actionsView
            case .processing:
                processingView
            case .success(let result, let model):
                previewView(result: result, model: model)
            case .error(let message):
                errorView(message: message)
            }
        }
        .frame(minWidth: 400, maxWidth: .infinity)
        .background(.ultraThickMaterial)
    }

    private var actionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(categories) { category in
                    Text(category.name)
                        .font(.system(size: 11))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                    ForEach(category.actions) { action in
                        Button(action: {
                            guard let composed = action.composePrompt(text: content.text, imagePath: content.imagePath) else { return }
                            executeAction(prompt: composed, model: action.model)
                        }) {
                            Text(action.name)
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 1)
                    }
                }

                Divider()
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Eigen prompt:")
                        .font(.system(size: 11))
                        .foregroundColor(Color(NSColor.secondaryLabelColor))

                    SubmitTextEditor(text: $freeformText) {
                        submitFreeform()
                    }
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                    .frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Verwerken...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func previewView(result: String, model: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Resultaat")
                    .font(.system(size: 11))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .textCase(.uppercase)

                Spacer()

                Text(model ?? "default")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(NSColor.quaternaryLabelColor))
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)

            ScrollView {
                Text(result)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)
            .padding(.horizontal, 12)

            HStack(spacing: 10) {
                Button("Terug") {
                    state = .idle
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Kopieer") {
                    onCopy(result)
                }
                .buttonStyle(.bordered)

                if content.hasText {
                    Button("Vervang") {
                        onReplace(result)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Text("Fout")
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Terug") {
                state = .idle
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func submitFreeform() {
        let instruction = freeformText.trimmingCharacters(in: .whitespaces)
        guard !instruction.isEmpty else { return }
        let composed = PromptAction.composeFreeformPrompt(instruction: instruction, text: content.text, imagePath: content.imagePath)
        executeAction(prompt: composed)
    }

    private func executeAction(prompt: String, model: String? = nil) {
        state = .processing
        Task {
            if let result = await onAction(prompt, model) {
                await MainActor.run {
                    state = .success(result: result, model: model)
                }
            } else {
                await MainActor.run {
                    state = .idle
                }
            }
        }
    }
}
