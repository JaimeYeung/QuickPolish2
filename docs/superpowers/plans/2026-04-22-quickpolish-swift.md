# QuickPolish Swift — Implementation Plan (As-Built)

**Original plan date:** 2026-04-22
**Revised:** 2026-04-23 to match what was actually built after the first
debug + rework pass.

This document records what was built, in the order it was built, and what
changed from the initial plan. For the current design rationale, see
[`docs/superpowers/specs/2026-04-22-quickpolish-swift-design.md`](../specs/2026-04-22-quickpolish-swift-design.md).

---

## Goal

Build a macOS background app in Swift that rewrites user-selected text via
the OpenAI API on ⌃G, showing a floating preview with three rewrite modes
(Natural / Professional / Shorter).

## Architecture

Two SPM targets:

- `QuickPolish2` — executable, a thin `main.swift` entry point
- `QuickPolish2Core` — library containing all business logic, so most of it
  is unit-testable without building the app binary

## Tech Stack

Swift 5.9+, SwiftUI, AppKit, Carbon `RegisterEventHotKey`, `CGEvent`,
`NSPasteboard`, `URLSession` async/await, XCTest.

---

## File Map (final)

| File | Target | Responsibility |
|------|--------|----------------|
| `Package.swift` | — | SPM manifest, two targets, macOS 13+ |
| `Sources/QuickPolish2/main.swift` | Executable | `NSApplication` entry point |
| `Sources/QuickPolish2Core/Models.swift` | Library | `RewriteMode`, `RewriteResult`, `PreviewState` |
| `Sources/QuickPolish2Core/Config.swift` | Library | Reads `OPENAI_API_KEY` from `~/.quickpolish/.env.local` |
| `Sources/QuickPolish2Core/Rewriter.swift` | Library | `URLSessionProtocol` + `Rewriter` + prompts + structured `RewriterError` |
| `Sources/QuickPolish2Core/TextAccessor.swift` | Library | `NSPasteboard` read + `CGEvent` ⌘V synth |
| `Sources/QuickPolish2Core/HotkeyManager.swift` | Library | Carbon `RegisterEventHotKey` for ⌃G |
| `Sources/QuickPolish2Core/PreviewViewModel.swift` | Library | `ObservableObject` bridging state → SwiftUI |
| `Sources/QuickPolish2Core/PreviewView.swift` | Library | SwiftUI panel contents: text, mode pills, buttons |
| `Sources/QuickPolish2Core/PreviewPanel.swift` | Library | `NSPanel` subclass, non-key, floating |
| `Sources/QuickPolish2Core/HintPanel.swift` | Library | Transient "copy text first" toast |
| `Sources/QuickPolish2Core/AppDelegate.swift` | Library | Menubar, hotkey wiring, panel lifecycle |
| `Sources/QuickPolish2Core/DebugLog.swift` | Library | NSLog + file logger at `~/.quickpolish/quickpolish.log` |
| `Tests/QuickPolish2Tests/ModelsTests.swift` | Test | `RewriteResult` + `PreviewViewModel` |
| `Tests/QuickPolish2Tests/ConfigTests.swift` | Test | `.env.local` parsing |
| `Tests/QuickPolish2Tests/RewriterTests.swift` | Test | Mock URLSession, error paths |
| `scripts/setup-signing.sh` | — | One-time: create self-signed cert in login keychain |
| `scripts/run.sh` | — | Build + sign with stable identity + relaunch |

---

## Build Order

Executed roughly in this sequence. Each step ended at a clean commit.

1. **Project skeleton** — `Package.swift`, `main.swift`, `.gitignore`,
   empty directory structure. `swift build` succeeds.
2. **`Models.swift`** — TDD. Tests in `ModelsTests.swift` define
   `RewriteMode`, `RewriteResult`, `PreviewState` shape before
   implementation.
3. **`Config.swift`** — originally written with a `KeychainService`
   protocol + `SystemKeychain` implementation. Later replaced with
   `.env.local` reader (see Revision 3 below).
4. **`Rewriter.swift`** — TDD with `URLSessionProtocol` mock. Covered
   happy path, auth header, and network failure. Extended later to use a
   structured `RewriterError` enum (see Revision 4).
5. **`TextAccessor.swift`** — initially read selected text via
   `AXUIElementCopyAttributeValue(kAXFocusedUIElementAttribute,
   kAXSelectedTextAttribute)`. Later replaced with clipboard-only read
   (see Revision 1).
6. **`HotkeyManager.swift`** — initially used
   `NSEvent.addGlobalMonitorForEvents(.keyDown)`. Later replaced with
   Carbon `RegisterEventHotKey` (see Revision 2).
7. **`PreviewViewModel` + `PreviewView`** — SwiftUI glass-morphism panel,
   with `@ObservedObject` bridging to state.
8. **`PreviewPanel`** — `NSPanel` subclass with
   `styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless]`
   and `canBecomeKey = false`.
9. **`AppDelegate`** — menubar status item, hotkey wiring, `showPreview`
   orchestration.
10. **Manual integration + README** — ran against Gmail/Notes/Chrome,
    wrote README, opened GitHub issues for what didn't work.

Tests (18 total) green after each step where they were added.

---

## Revisions After First Debug Pass

The initial implementation followed the original spec closely but several
things broke or didn't behave the way the spec assumed. Documenting the
changes here because they define how the shipping code differs from the
original plan.

### Revision 1 — TextAccessor: clipboard-only

**Original:** `getSelectedText()` used `AXUIElement` to read the focused
element's `kAXSelectedTextAttribute`.

**Problem:** The AX API silently returned empty / nil / `kAXErrorNoValue`
in a large fraction of target apps — Chrome text boxes, Electron apps
(Notion, Slack), anything WebKit-hosted, and anywhere the focus chain
wasn't fully exposed. Notes.app worked; most else didn't.

**Fix:** Removed `getSelectedText()` entirely. Replaced with
`getClipboardText()` that reads `NSPasteboard.general.string(forType:
.string)`. User is now expected to press **⌘C first, then ⌃G**.

**Trade-off:** One extra keystroke, in exchange for 100% reliability across
every macOS app. Also eliminated the Accessibility permission requirement
altogether.

### Revision 2 — HotkeyManager: Carbon instead of NSEvent

**Original:** `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`.

**Problem:** `addGlobalMonitorForEvents` silently requires Input
Monitoring permission (macOS doesn't prompt; it just delivers nothing).
Plus, it wakes on every single global keystroke and filters in-process,
which is wasteful.

**Fix:** Carbon `RegisterEventHotKey(kVK_ANSI_G, controlKey, …)` +
`InstallEventHandler`. Carbon's hotkey mechanism needs no special
permission for system-wide registration and only fires when the specific
chord matches.

### Revision 3 — Config: `.env.local` instead of Keychain

**Original:** `KeychainService` protocol + `SystemKeychain` +
`Config.shared.apiKey` get/set writing to
`kSecClassGenericPassword(com.quickpolish.openai-key)`.

**Problem:** For an unbundled Mach-O executable, Keychain access requires
entitlements and a signed Info.plist. Easier to just read from a dotfile.

**Fix:** `Config.apiKey` re-reads `~/.quickpolish/.env.local` on every
access and parses `OPENAI_API_KEY=…`. Menubar → "Set API Key…" opens the
file in the default editor.

**Bonus:** Changing the API key no longer needs an app restart.

### Revision 4 — Rewriter: structured errors + safer JSON parsing

**Original:** Used forced unwraps to navigate OpenAI's JSON response.

**Problem:** The app crashed with `Unexpectedly found nil while
unwrapping an Optional value` whenever OpenAI returned an error body (bad
key, rate limit, model-not-found, etc.) because those responses don't
have a `choices` field.

**Fix:** Added `RewriterError` enum with `.networkFailure`, `.apiError`,
`.badJSON` cases. All forced unwraps replaced with safe unwrapping.
Per-mode failures fill in `[error: <description>]` placeholders; if all
three modes fail, `result.error` is set too so the UI can surface it.
Default model changed `gpt-4o` → `gpt-4o-mini` for broader key
compatibility.

### Revision 5 — Debug scaffolding added, then cleaned up

During debugging the app grew a lot of temporary surface:
- "Test Rewrite (simulate ⌃G)" menu item
- An `NSAlert` showing API key / AX trust / selected text
- Flashing menubar icon (`bolt.fill` for success,
  `exclamationmark.triangle.fill` for failure)
- Menu markers showing `launched` timestamp and last ⌃G time
- `NSMenuDelegate` to refresh the last-⌃G label on menu open
- "Open Log…" menu item

All of this was removed once the core flow worked. The only survivor is
`DebugLog` (NSLog + `~/.quickpolish/quickpolish.log` file logger), which
costs ~nothing and is useful for future diagnostics.

### Revision 6 — Empty clipboard UX

Added `HintPanel.swift` — a transient floating panel that appears near
the top of the screen when the user presses ⌃G with an empty clipboard,
showing "Clipboard is empty / Copy text with ⌘C first, then press ⌃G."
Fades in, sits 2.4s, fades out. Non-activating, like `PreviewPanel`.

### Revision 7 — Stable code signing (scripts/)

**Problem discovered during debug loop:** Every `swift build` generates a
new `cdhash`, which invalidates every TCC permission tied to that
binary. The user was re-granting Accessibility / Input Monitoring dozens
of times across a single debugging session.

**Fix:** Two scripts that together make the signature identity stable
across rebuilds, so TCC's designated requirement stays constant and
grants persist:

- **`scripts/setup-signing.sh`** — one-time. Generates a self-signed
  `QuickPolishLocal` code-signing cert via LibreSSL (Mac's `/usr/bin/openssl`,
  because Anaconda's OpenSSL 3 produces PKCS12 files `security` rejects),
  bundles it with legacy PBE-SHA1-3DES + SHA1 MAC (plus a throwaway
  password — `security import` refuses empty-password p12s), imports
  into login keychain with `-T /usr/bin/codesign` and runs
  `security set-key-partition-list` so codesign doesn't prompt.
- **`scripts/run.sh`** — every build. Verifies identity exists
  (unfiltered `find-identity`, since self-signed shows as
  `CSSMERR_TP_NOT_TRUSTED` which is fine), runs `swift build`, then
  `codesign --force --sign QuickPolishLocal -i com.quickpolish.QuickPolish2`.
  The `-i` identifier plus the cert's CN form the stable DR. Kills any
  existing process and relaunches in background.

After switching to `scripts/run.sh`, Input Monitoring grant survives
arbitrary rebuilds.

---

## Tests

18 tests across 3 files. All green on `swift test`.

- **ModelsTests (11)** — `RewriteMode.allCases.count`, `RewriteResult`
  lookups, `hasError` flag logic, `PreviewViewModel` state transitions
  (loading → ready, mode switching, error state).
- **ConfigTests (4)** — `.env.local` absent → `apiKey == nil`; missing
  key → nil; empty value → nil; present key parses correctly.
- **RewriterTests (3)** — happy path returns results for all three
  modes; `Authorization: Bearer <key>` header is set correctly; network
  failure fills every mode with an `[error: …]` placeholder AND sets
  top-level `result.error`.

`TextAccessor`, `HotkeyManager`, `PreviewPanel`, `PreviewView`,
`AppDelegate`, `HintPanel`, `DebugLog` are integration-only — they wrap
system APIs with no meaningful branching logic worth a unit test.

---

## Manual Integration Checklist

After `./scripts/setup-signing.sh` + `./scripts/run.sh`:

- [ ] ✦ icon appears in menubar
- [ ] Menubar click shows menu: "Copy text, then press ⌃G" (disabled label) /
      "Set API Key…" / "Quit QuickPolish"
- [ ] `tail -f ~/.quickpolish/quickpolish.log` shows `app launched — pid=…`
- [ ] Select text anywhere → ⌘C → ⌃G → preview panel opens
- [ ] Loading spinner shows, then three results populate in parallel
- [ ] Clicking Natural / Professional / Shorter swaps the displayed text
- [ ] Clicking **Replace** closes the panel and pastes into the originally
      focused text field (requires Input Monitoring permission granted)
- [ ] Clicking **Cancel** just closes the panel; clipboard still has the
      user's original copy
- [ ] ⌃G with empty clipboard → HintPanel appears top-of-screen, disappears
      on its own after ~2.4s
- [ ] Invalid API key → preview shows `[error: API 401: Incorrect API key
      provided …]` instead of crashing
- [ ] Rebuilding via `./scripts/run.sh` does not require re-granting any
      permissions

---

## Permissions Note

With Revision 1 (clipboard-only read) and Revision 2 (Carbon hotkey), the
only permission the app ever requests is **Input Monitoring**, and only
the first time the user hits Replace (for synthesizing ⌘V). Grant once:

> System Settings → Privacy & Security → Input Monitoring → toggle on
> QuickPolish2

Thanks to stable signing (Revision 7), the grant survives rebuilds.
