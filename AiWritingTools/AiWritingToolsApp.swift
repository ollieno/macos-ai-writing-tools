import SwiftUI

@main
struct AiWritingToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("AI Writing Tools", systemImage: "text.bubble") {
            Text("Cmd+Shift+A om tekst te verwerken")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
            Button("Open Prompts Map") {
                NSWorkspace.shared.open(PromptLibrary.promptsDirectory)
            }
            Divider()
            Button("Stop AI Writing Tools") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
