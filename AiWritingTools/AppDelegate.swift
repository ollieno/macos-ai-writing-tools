import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyManager = HotkeyManager()
    let textProcessor = TextProcessor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
        if runningInstances.count > 1 {
            NSApp.terminate(nil)
            return
        }

        let isFirstRun = !FileManager.default.fileExists(atPath: PromptLibrary.promptsDirectory.path)

        do {
            try SeedPrompts.installIfNeeded(to: PromptLibrary.promptsDirectory)
        } catch {
            NSLog("Failed to seed prompts: \(error)")
        }

        // Check accessibility permission
        if !TextAccessor.isAccessibilityGranted() {
            _ = TextAccessor.ensureAccessibilityPermission()
        }

        // Register global hotkey: Cmd+Shift+A
        hotkeyManager.register { [weak self] in
            self?.textProcessor.processSelectedText()
        }

        if isFirstRun {
            showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    private func showWelcome() {
        let alert = NSAlert()
        alert.messageText = "Welkom bij AI Writing Tools"
        alert.informativeText = "AI Writing Tools is nu klaar voor gebruik!\n\nDruk op Cmd+Shift+A om geselecteerde tekst te verwerken met AI.\n\nZorg dat Accessibility-toegang is ingeschakeld in Systeeminstellingen > Privacy en beveiliging > Toegankelijkheid.\n\nJe prompts staan in:\n~/Library/Application Support/AiWritingTools/prompts/"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Begrepen")
        alert.addButton(withTitle: "Open Prompts Map")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(PromptLibrary.promptsDirectory)
        }
    }
}
