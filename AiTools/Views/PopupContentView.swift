import SwiftUI

struct PopupContentView: View {
    let categories: [PromptCategory]
    let selectedText: String
    let onAction: (String) async -> Void
    let onDismiss: () -> Void

    @State private var freeformText = ""
    @State private var state: ProcessingState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AiTools")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            if case .processing = state {
                processingView
            } else if case .error(let message) = state {
                errorView(message: message)
            } else {
                actionsView
            }
        }
        .frame(width: 320)
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
                            guard let composed = action.composePrompt(with: selectedText) else { return }
                            executeAction(prompt: composed)
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

                    HStack(spacing: 6) {
                        TextField("Typ je instructie...", text: $freeformText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(8)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(6)
                            .onSubmit {
                                submitFreeform()
                            }

                        Button("Ga") {
                            submitFreeform()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(freeformText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
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
        let composed = PromptAction.composeFreeformPrompt(instruction: instruction, text: selectedText)
        executeAction(prompt: composed)
    }

    private func executeAction(prompt: String) {
        state = .processing
        Task {
            await onAction(prompt)
        }
    }
}
