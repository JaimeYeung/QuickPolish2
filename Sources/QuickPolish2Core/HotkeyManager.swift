import AppKit
import Carbon.HIToolbox

public final class HotkeyManager {
    public var onHotkey: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    public init() {}

    public func startListening() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let ptr = userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { manager.onHotkey?() }
                return noErr
            },
            1, &eventType, selfPtr, &eventHandler
        )

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = 0x51504753  // 'QPGS'
        hotKeyID.id = 1

        // Control+G: kVK_ANSI_G = 5, controlKey modifier
        RegisterEventHotKey(
            UInt32(kVK_ANSI_G),
            UInt32(controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        print("[QP] Carbon hotkey registered: Ctrl+G")
    }

    public func stopListening() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit { stopListening() }
}
