import SwiftUI

@main
struct AiToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("AiTools", systemImage: "text.bubble") {
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
