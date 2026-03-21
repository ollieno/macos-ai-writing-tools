import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    let serviceProvider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isFirstRun = !FileManager.default.fileExists(atPath: PromptLibrary.promptsDirectory.path)

        do {
            try SeedPrompts.installIfNeeded(to: PromptLibrary.promptsDirectory)
        } catch {
            NSLog("Failed to seed prompts: \(error)")
        }

        NSApplication.shared.servicesProvider = serviceProvider
        NSUpdateDynamicServices()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        if isFirstRun {
            showWelcome()
        }
    }

    private func showWelcome() {
        let alert = NSAlert()
        alert.messageText = "Welkom bij AiTools"
        alert.informativeText = "AiTools is nu beschikbaar via het Services-menu.\n\nSelecteer tekst in een willekeurige app, klik met de rechtermuisknop, en kies Services > \"Verwerk met AiTools\".\n\nJe prompts staan in:\n~/Library/Application Support/AiTools/prompts/"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Begrepen")
        alert.addButton(withTitle: "Open Prompts Map")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(PromptLibrary.promptsDirectory)
        }
    }
}
