import AppKit
import SwiftUI

final class PopupWindow {
    private var panel: NSPanel?
    private var isActive = false

    private var keyMonitor: Any?
    private var clickMonitor: Any?

    func show(
        text: String,
        categories: [PromptCategory],
        onAction: @escaping (String) async -> String?,
        onComplete: @escaping (String?) -> Void
    ) {
        guard !isActive else { return }
        isActive = true

        let contentView = PopupContentView(
            categories: categories,
            selectedText: text,
            onAction: { composedPrompt in
                let result = await onAction(composedPrompt)
                await MainActor.run {
                    onComplete(result)
                }
            },
            onDismiss: { [weak self] in
                self?.dismiss()
                onComplete(nil)
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 400)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.level = .floating
        panel.backgroundColor = .clear

        var origin = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        origin.x = min(origin.x, screenFrame.maxX - 320)
        origin.y = max(origin.y - 400, screenFrame.minY)
        panel.setFrameOrigin(origin)

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                onComplete(nil)
                return nil
            }
            return event
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.dismiss()
            onComplete(nil)
        }
    }

    func dismiss() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        keyMonitor = nil
        clickMonitor = nil
        panel?.close()
        panel = nil
        isActive = false
    }
}
