import AppKit

public struct TextAccessor {

    /// Reads non-empty plain text off the general pasteboard, or `nil` if the
    /// pasteboard has nothing usable. The workflow is intentional:
    ///
    ///     1. User selects text in any app
    ///     2. User presses Cmd+C
    ///     3. User presses Ctrl+G
    ///
    /// This sidesteps every failure mode of Accessibility / AXUIElement —
    /// works reliably in Chrome, Notion, Electron apps, browser text boxes,
    /// terminal, the system-wide selection in Notes, everywhere.
    public static func getClipboardText() -> String? {
        guard let raw = NSPasteboard.general.string(forType: .string) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : raw
    }

    /// Writes text to the clipboard and simulates Cmd+V so it lands in
    /// whatever app had focus when the hotkey fired. The `NSPanel` we show
    /// never takes keyboard focus, so the target element is still receiving
    /// keystrokes here.
    public static func pasteText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
