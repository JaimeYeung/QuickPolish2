import AppKit

public final class HotkeyManager {
    public var onHotkey: (() -> Void)?
    private var monitor: Any?

    public init() {}

    public func startListening() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Control+G only — keyCode 5, no other modifiers
            let onlyControl = event.modifierFlags
                .intersection([.control, .command, .option, .shift]) == .control
            if event.keyCode == 5 && onlyControl {
                DispatchQueue.main.async { self?.onHotkey?() }
            }
        }
    }

    public func stopListening() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit { stopListening() }
}
