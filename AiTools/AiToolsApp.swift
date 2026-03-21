import SwiftUI

@main
struct AiToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("AiTools", systemImage: "text.bubble") {
            Text("Cmd+Shift+A om tekst te verwerken")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
            Button("Open Prompts Map") {
                NSWorkspace.shared.open(PromptLibrary.promptsDirectory)
            }
            Divider()
            Button("Stop AiTools") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
