# QuickPolish Swift — Design Spec
Date: 2026-04-22

## Overview

A macOS background app built in SwiftUI that rewrites selected text using the OpenAI API. Press Control+G on any selected text in any app, see a floating preview with three rewrite modes, click Replace to swap the text in place.

Built in Swift/SwiftUI for macOS 15+ (Sequoia). The window never steals keyboard focus, solving the paste reliability issues of the Python version entirely.

---

## User Flow

1. Select text in any macOS app (Gmail, Notion, Messages, etc.)
2. Press **Control+G**
3. App reads selected text via `AXUIElement` (no Cmd+C needed)
4. Floating panel appears — Chrome/any app keeps keyboard focus throughout
5. Three parallel OpenAI API requests fire immediately
6. Preview shows Natural result by default; click mode pills to switch
7. Click **Replace** → result written to clipboard → Cmd+V → text replaced
8. Or click **Cancel** → panel closes, original text unchanged

---

## Why Swift Solves the Paste Problem

The Python version failed because tkinter windows steal keyboard focus from Chrome, causing Gmail's compose box to lose its selection. In Swift:

- `NSPanel` with `NSWindowStyleMask.nonactivatingPanel` **never** takes keyboard focus
- Chrome/Gmail compose box stays focused the entire time
- Cmd+V fires while the target element is still focused → paste always works

---

## Rewrite Modes

| Mode | Prompt |
|------|--------|
| **Natural** | Understand the intended meaning and express it the way you'd say it to a friend — casual, chill, natural American English. Not a grammar fix, not a translation. Think: how would a native speaker say this in a text message? |
| **Professional** | Understand the intended meaning and express it for a professional email context. Sound confident, direct, and warm — like a real person, not a robot. No corporate filler: no "I hope this email finds you well", no "please don't hesitate to reach out", no "as per my previous email". |
| **Shorter** | Understand the intended meaning, express it in natural American English, then cut it down. Remove redundancy without losing the point. Keep the appropriate register. |

### Shared constraints
- Always output English only
- Input may be Chinese, English, or Chinglish — always output natural American English
- Do not translate literally — understand intent, express it naturally
- Do not sound like AI. No filler phrases
- Return ONLY the rewritten text, nothing else

---

## Architecture

Background-only app (no Dock icon). Menubar icon for settings and quit.

```
QuickPolishApp.swift    — App entry point, LSUIElement background app
AppDelegate.swift       — NSStatusItem menubar icon, Accessibility permission check
HotkeyManager.swift     — NSEvent global monitor for Ctrl+G
TextAccessor.swift      — AXUIElement: read selected text + clipboard paste to replace
Rewriter.swift          — OpenAI API, 3 parallel async/await requests, prompts
PreviewPanel.swift      — NSPanel subclass, nonactivatingPanel + floating
PreviewView.swift       — SwiftUI UI: text display, mode pills, Replace/Cancel buttons
Config.swift            — API key stored in macOS Keychain
Models.swift            — Mode enum, RewriteState struct
```

---

## UI Design

Dark frosted glass floating panel, always on top, centered on screen.

```
┌─────────────────────────────────────────┐
│  ✦ QuickPolish                          │  ← title bar, dark
├─────────────────────────────────────────┤
│                                         │
│  Hey Matt, thanks for setting up the    │  ← rewritten text
│  interview. Didn't see the link —       │
│  is it over the phone or Zoom?          │
│                                         │
├─────────────────────────────────────────┤
│  ╭──────────╮ ╭──────────────╮ ╭──────╮ │  ← glass morphism pills
│  │ Natural  │ │ Professional │ │Short │ │
│  ╰──────────╯ ╰──────────────╯ ╰──────╯ │
├─────────────────────────────────────────┤
│      [ Replace ]           [ Cancel ]   │
└─────────────────────────────────────────┘
```

**Mode pills (glass morphism on macOS 15):**
- Background: `.ultraThinMaterial`
- Border: gradient stroke (white 30% opacity top-left → clear bottom-right)
- Shadow: soft drop shadow
- Selected: accent color tint + brighter border
- On macOS 26+: swap to `.glassEffect()` directly

**Loading state:** spinner + "Rewriting…" text while API calls in flight.

**Colors:** dark background `#1C1C1E`, text white, accent blue `#5B9CF6`, muted gray `#636366`.

---

## Text Access

**Reading selected text:**
```swift
// Via AXUIElement — no Cmd+C needed
let systemElement = AXUIElementCreateSystemWide()
var focusedElement: CFTypeRef?
AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
var selectedText: CFTypeRef?
AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
```

**Replacing text:**
```swift
// Write to clipboard, then simulate Cmd+V
// NSPanel never stole focus, so target app's element is still focused
NSPasteboard.general.clearContents()
NSPasteboard.general.setString(result, forType: .string)
// Simulate Cmd+V via CGEvent
let src = CGEventSource(stateID: .hidSystemState)
let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
keyDown?.flags = .maskCommand
keyUp?.flags = .maskCommand
keyDown?.post(tap: .cghidEventTap)
keyUp?.post(tap: .cghidEventTap)
```

---

## Configuration

API key stored in macOS Keychain (`com.quickpolish.openai-key`). First launch shows a setup sheet to enter the key. Accessible from menubar icon.

---

## macOS Permissions Required

- **Accessibility** — to read selected text via AXUIElement and simulate Cmd+V
- Prompted on first launch with instructions to System Settings

---

## Info.plist Keys

```xml
<key>LSUIElement</key><true/>          <!-- background app, no Dock icon -->
<key>NSAccessibilityUsageDescription</key>
<string>QuickPolish needs Accessibility access to read your selected text and paste the rewritten version.</string>
```

---

## Out of Scope (MVP)

- Custom prompt editing
- History of past rewrites
- iOS / iPadOS version
- iCloud sync
- Distributing a pre-signed .app (users build from source)
