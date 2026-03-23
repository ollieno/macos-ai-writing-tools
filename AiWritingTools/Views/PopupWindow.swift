import AppKit
import SwiftUI

final class PopupWindow {
    private var panel: NSPanel?
    private var isActive = false

    private var keyMonitor: Any?
    private var clickMonitor: Any?

    func show(
        content: ClipboardContent,
        categories: [PromptCategory],
        onAction: @escaping (String, String?) async -> String?,
        onReplace: @escaping (String) -> Void,
        onCopy: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard !isActive else { return }
        isActive = true

        let contentView = PopupContentView(
            categories: categories,
            content: content,
            onAction: onAction,
            onReplace: { [weak self] result in
                self?.dismiss()
                onReplace(result)
            },
            onCopy: { [weak self] result in
                self?.dismiss()
                onCopy(result)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
                onCancel()
            }
        )

        let width: CGFloat = 520
        let height: CGFloat = 580

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 12
        panel.contentView?.layer?.masksToBounds = true
        panel.minSize = NSSize(width: 400, height: 300)

        var origin = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        origin.x = min(origin.x, screenFrame.maxX - width)
        origin.y = max(origin.y - height, screenFrame.minY)
        panel.setFrameOrigin(origin)

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                onCancel()
                return nil
            }
            return event
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let panel = self?.panel else { return }
            let clickLocation = event.locationInWindow == .zero ? NSEvent.mouseLocation : event.locationInWindow
            let mouseLocation = NSEvent.mouseLocation
            if panel.frame.contains(mouseLocation) { return }
            self?.dismiss()
            onCancel()
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
