import Carbon.HIToolbox
import AppKit

/// A single global hot key registered via Carbon. Fires `callback` on the main
/// thread when pressed. Default binding: ⌘⌥N to toggle the notch dashboard.
final class HotKey: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let callback: () -> Void

    init?(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.callback = callback

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            me.callback()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)
        guard installStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4C454447), id: 1) // 'LEDG'
        let regStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                            GetApplicationEventTarget(), 0, &hotKeyRef)
        guard regStatus == noErr else { return nil }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
