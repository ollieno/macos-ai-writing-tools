import AppKit
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
            Button("Over AI Writing Tools") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            Divider()
            Button("Stop AI Writing Tools") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
