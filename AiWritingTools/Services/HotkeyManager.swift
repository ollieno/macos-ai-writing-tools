import Carbon
import AppKit

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?

    // Store a global reference so the C callback can access it
    private static var shared: HotkeyManager?

    func register(handler: @escaping () -> Void) {
        self.handler = handler
        HotkeyManager.shared = self

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4149_5448) // "AITH"
        hotKeyID.id = 1

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                if hkID.id == 1 {
                    DispatchQueue.main.async {
                        HotkeyManager.shared?.handler?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        // Cmd+Shift+A: key code 0 = A key
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_A),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
