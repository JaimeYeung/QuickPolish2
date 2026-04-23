# QuickPolish Swift — Design Spec

**Date:** 2026-04-22 (revised 2026-04-23 to match as-built code)

## Overview

A macOS background app built in Swift/SwiftUI/AppKit that rewrites clipboard
text using the OpenAI API. User copies text (⌘C), presses **⌃G**, sees a
floating preview with three rewrite modes, clicks Replace to paste the
rewritten version into wherever they were typing.

Targets macOS 13+. No Dock icon — menubar-only background app
(`.accessory` activation policy).

---

## User Flow

1. User selects text in any macOS app (Gmail, Notion, Terminal, Chrome, …)
2. User presses **⌘C** to copy it to the clipboard
3. User presses **⌃G**
4. QuickPolish reads the clipboard, shows a floating `NSPanel`, and fires three
   OpenAI API calls in parallel
5. Preview renders Natural by default; clicking a mode pill switches the view
6. User clicks **Replace** → QuickPolish writes the chosen rewrite to the
   clipboard and synthesizes ⌘V, replacing the originally selected text
7. Or user clicks **Cancel** → panel closes, clipboard still holds the
   original text the user had copied
8. If the clipboard is empty when ⌃G is pressed, a small transient hint panel
   floats in from the top of the screen (`HintPanel`) telling the user to
   copy text first

---

## Why ⌘C → ⌃G (Instead of Just ⌃G on Selection)

**The first iteration** tried reading the selection directly via
`AXUIElement` (`AXUIElementCopyAttributeValue` with
`kAXSelectedTextAttribute`). This was abandoned because:

- `AXUIElement` requires Accessibility permission, which is TCC-tracked by
  cdhash. Swift Package Manager's ad-hoc signing gives every rebuild a
  fresh cdhash, so the permission dies every time you recompile.
- Even with permission granted, the API silently fails in Electron apps,
  Chrome text fields, and many browser-hosted editors (Gmail, Notion, most
  rich text inputs) because those apps don't expose focused-element
  attributes through the standard AX path.
- The fallback of synthesizing ⌘C ourselves and reading the clipboard
  worked in some apps but was flaky and introduced race conditions with
  pasteboard restoration.

**Lifting the ⌘C responsibility to the user** makes the "read" side 100%
reliable in exchange for one extra keystroke. Reading from
`NSPasteboard.general` works identically in every app, requires no special
permission, and has zero timing issues.

---

## Permissions Required

- **Input Monitoring** — to synthesize ⌘V via `CGEvent.post(tap:)`. Prompted
  by macOS on first Replace. Grant persists across rebuilds when the binary
  is signed with a stable identity (see Stable Signing below).
- **Accessibility** — **not required**. Removed entirely compared to the
  first iteration.

---

## Rewrite Modes

| Mode | Prompt intent |
|------|---------------|
| **Natural** | Casual American English, like texting a friend. Chill and real. |
| **Professional** | Confident, direct, warm email tone. Explicitly rejects corporate filler ("I hope this email finds you well", "please don't hesitate to reach out", etc.). |
| **Shorter** | Natural American English, then trimmed. Remove redundancy, keep meaning and tone. |

### Shared constraints (system prompt)
- Output English only, regardless of input language
- Input may be Chinese, English, or Chinglish
- Don't translate literally — understand intent, express it naturally
- Don't sound like AI. No filler phrases
- Return ONLY the rewritten text — no quotes, no explanation

Default model: `gpt-4o-mini` (swap via `Rewriter.init(model:)`).

---

## Architecture

Two SPM targets:

- **`QuickPolish2`** (executable) — thin `main.swift` that sets the
  activation policy and hands off to `AppDelegate`.
- **`QuickPolish2Core`** (library) — all business logic, testable.

### File map

```
Sources/QuickPolish2/main.swift             — NSApplication entry point
Sources/QuickPolish2Core/
  AppDelegate.swift                         — menubar, hotkey, panel lifecycle
  HotkeyManager.swift                       — Carbon RegisterEventHotKey ⌃G
  TextAccessor.swift                        — clipboard read + ⌘V synthesis
  Rewriter.swift                            — OpenAI API, 3-way parallel async
  Config.swift                              — reads OPENAI_API_KEY from
                                              ~/.quickpolish/.env.local
  Models.swift                              — RewriteMode, RewriteResult,
                                              PreviewState enums
  PreviewViewModel.swift                    — @Published ObservableObject
  PreviewView.swift                         — SwiftUI panel contents
  PreviewPanel.swift                        — NSPanel subclass (non-key)
  HintPanel.swift                           — transient "copy first" toast
  DebugLog.swift                            — NSLog + file logger
                                              (~/.quickpolish/quickpolish.log)

Tests/QuickPolish2Tests/
  ModelsTests.swift                         — RewriteResult + ViewModel
  ConfigTests.swift                         — .env.local parsing
  RewriterTests.swift                       — URLSession mock + error paths

scripts/
  setup-signing.sh                          — one-time: create self-signed
                                              cert in login keychain
  run.sh                                    — swift build + codesign +
                                              kill old pid + relaunch
```

### Hotkey registration

`HotkeyManager` uses Carbon's `RegisterEventHotKey` + `InstallEventHandler`
against the application event target. This intentionally does **not** use
`NSEvent.addGlobalMonitorForEvents`, which requires Input Monitoring just to
observe the hotkey. Carbon's mechanism needs no special permission for
system-wide registration.

---

## UI Design

Centered floating panel, dark frosted glass, ~460×280 pt.

```
┌─────────────────────────────────────────┐
│  ✦ QuickPolish                          │  ← title bar
├─────────────────────────────────────────┤
│                                         │
│  Rewritten text appears here, scrollable│
│  if it's long, selectable so the user   │
│  can read it cleanly.                   │
│                                         │
├─────────────────────────────────────────┤
│  ╭─────────╮  Professional   Shorter    │  ← mode pills
│  │ Natural │                            │
│  ╰─────────╯                            │
├─────────────────────────────────────────┤
│  Cancel                       [Replace] │
└─────────────────────────────────────────┘
```

- Background: `.ultraThinMaterial` + 45% black overlay for readability on
  light desktops
- Colors: dark background `#1C1C1E`, text white, accent blue `#5B9CF6`,
  muted gray `#636366`
- Shadow: soft drop shadow from the SwiftUI view itself (NSPanel
  `hasShadow = false` to avoid double shadow)
- Loading: spinner + "Rewriting…" while API calls are in flight
- Error: red text showing the API error message (e.g. `[error: API 401:
  Incorrect API key provided]`)

### Panel focus behavior

`PreviewPanel.canBecomeKey` and `canBecomeMain` both return `false`. This
is a deliberate trade-off:

- **Pro**: Replace works reliably. The original app still has keyboard
  focus when we synthesize ⌘V, so the paste lands in the right text field.
- **Con**: The panel can't receive keyboard events, so Tab / Enter / Esc
  don't work as shortcuts. Users must click buttons / pills.

This is the known UX weakness vs. the Python version of QuickPolish, which
sidesteps it by (a) letting its Tk window take focus and (b) using
`osascript … tell application "<target>" to activate` to switch focus back
before pasting. A future iteration could adopt the same approach (track the
frontmost app at hotkey time, activate it before the Replace key synth,
enable Tab/Enter/Esc) — see Known Limitations below.

### Hint panel

`HintPanel` is a separate small floating panel (380×72 pt) that appears
near the top of the screen when the user presses ⌃G with an empty
clipboard. It fades in over 180 ms, stays 2.4 s, fades out over 220 ms.
Its content is an SF Symbol + title ("Clipboard is empty") + subtitle
("Copy text with ⌘C first, then press ⌃G").

---

## Text Access

### Reading (clipboard)

```swift
public static func getClipboardText() -> String? {
    guard let raw = NSPasteboard.general.string(forType: .string) else {
        return nil
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : raw
}
```

### Replacing (synthesized ⌘V)

```swift
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
```

Because `PreviewPanel` never became key, the original text field is still
focused when the synthesized ⌘V arrives.

---

## Configuration

API key lives in **`~/.quickpolish/.env.local`** as `OPENAI_API_KEY=sk-…`.
`Config.apiKey` rereads the file on every access so editing the file takes
effect on the next ⌃G without restarting the app.

The original design stored the key in Keychain; that was dropped because:

- Reading from Keychain requires entitlements for a signed bundle, adding
  friction for a local-dev Mach-O
- `.env.local` is trivial to edit with any editor
- The `.quickpolish` directory is already used for the log file, so no
  new filesystem footprint

Menubar → **Set API Key…** opens the file in the default text editor,
creating it with a template line if missing.

---

## Stable Code Signing (scripts/setup-signing.sh + scripts/run.sh)

macOS TCC (Transparency, Consent, and Control) tracks permissions by the
binary's designated requirement (DR). For an **ad-hoc-signed** binary the DR
includes the `cdhash`, which changes on every compile — so every rebuild
invalidates every permission grant. This made development unusable until we
introduced stable signing.

### setup-signing.sh (one-time)

1. If `QuickPolishLocal` identity already exists in login keychain, no-op
2. Use LibreSSL (`/usr/bin/openssl`, preferred over Homebrew/Anaconda
   OpenSSL 3 which produces PKCS12 bundles `security` can't read) to
   generate a self-signed cert with `extendedKeyUsage=codeSigning` and a
   matching RSA private key
3. Bundle into PKCS12 with `PBE-SHA1-3DES` / `SHA1 MAC` legacy algorithms
   (required by macOS Security.framework) and a throwaway password
   (`security import` refuses empty-password p12 even with legacy algos)
4. Import into login keychain with `-T /usr/bin/codesign` so codesign can
   use the key without a GUI prompt
5. `security set-key-partition-list` to skip the ACL prompt on first use

### run.sh (every build)

1. Check that `QuickPolishLocal` identity exists (unfiltered
   `security find-identity` — self-signed certs show up as
   `(CSSMERR_TP_NOT_TRUSTED)` under `-v`, but that's fine for local signing)
2. `swift build`
3. `codesign --force --sign QuickPolishLocal -i com.quickpolish.QuickPolish2 .build/debug/QuickPolish2`
   — the `-i` identifier is the other half of the DR, paired with the
   cert's Common Name
4. `codesign -dvvv` the binary, printing Identifier + Authority so the user
   can verify
5. `pkill -x QuickPolish2` then relaunch

Result: every rebuild has the **same DR** (`identifier
"com.quickpolish.QuickPolish2" and anchor <QuickPolishLocal>`), so macOS
keeps the Input Monitoring grant alive forever.

---

## Error Handling

`Rewriter` returns structured `RewriterError` values:

- `.networkFailure(String)` — URLSession threw (connection lost,
  DNS failure, …)
- `.apiError(status: Int, message: String)` — HTTP non-2xx (401 bad key,
  429 rate limit, 400 invalid model, …)
- `.badJSON(String)` — parseable response didn't match the expected shape
  (e.g. OpenAI returned `{"error": …}` where choices were expected)

`rewriteAll` runs all three modes concurrently via `withTaskGroup` and
swallows per-mode failures into `"[error: <description>]"` placeholders in
`result.results[mode]`. If all three modes fail with the same error,
`result.error` is also set so the UI can show a single top-level message.

All failures are logged to `~/.quickpolish/quickpolish.log` via
`DebugLog.info`.

---

## Known Limitations (vs. Python QuickPolish)

The Python version (<https://github.com/JaimeYeung/QuickPolish>) has a few
UX advantages this Swift version doesn't currently replicate:

1. **Preview is read-only.** Python version's Tk `Text` widget lets users
   edit the rewrite before pasting. Would require a SwiftUI `TextEditor`
   here, plus making the panel key-capable (see #2).
2. **No Tab/Enter/Esc keyboard navigation.** Panel can't be key without
   losing the focus-preservation trick. Python works around this by
   storing the frontmost app's name at hotkey time and calling
   `osascript activate` before the ⌘V. A Swift equivalent would use
   `NSWorkspace.shared.frontmostApplication` at hotkey time and
   `NSRunningApplication.activate` before paste.
3. **Still requires manual ⌘C.** Python synthesizes it internally using
   osascript + a sentinel clipboard value. Swift could do the same via
   `CGEvent` but would introduce the same timing/race complexity we
   already rejected once.
4. **No em/en dash sanitization.** Python `strip_ai_dashes` replaces
   em/en dashes with commas because GPT loves them and they look
   AI-generated. Trivial to port.

None of these were fixed in this iteration; documenting for future work.

---

## Out of Scope (MVP)

- Custom prompt editing
- History of past rewrites
- iOS / iPadOS version
- iCloud sync
- Pre-built signed `.app` bundle distribution (users build from source)
- Notarization / Gatekeeper-friendly distribution
