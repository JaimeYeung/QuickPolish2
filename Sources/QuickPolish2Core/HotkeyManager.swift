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

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let ptr = userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { manager.onHotkey?() }
                return noErr
            },
            1, &eventType, selfPtr, &eventHandler
        )

        if handlerStatus != noErr {
            DebugLog.info("❌ InstallEventHandler failed: OSStatus=\(handlerStatus)")
            return
        }

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = 0x51504753  // 'QPGS'
        hotKeyID.id = 1

        // Control+G: kVK_ANSI_G = 5, controlKey modifier
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_G),
            UInt32(controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus == noErr {
            DebugLog.info("✅ Carbon hotkey registered: Ctrl+G")
        } else {
            // -9878 = eventHotKeyExistsErr — another app owns this combo
            DebugLog.info("❌ RegisterEventHotKey failed: OSStatus=\(registerStatus)")
        }
    }

    public func stopListening() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit { stopListening() }
}
