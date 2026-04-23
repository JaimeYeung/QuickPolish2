# QuickPolish

Writing in English takes extra effort when it's not your first language. You know what you want to say, but getting it to sound right takes time. And fixing it usually means jumping to another app, copy-pasting, then switching back.

QuickPolish cuts out all of that. Select any text, press a hotkey, and get a polished version in seconds without leaving what you're working on. Works in any macOS app: Gmail, Notion, Slack, Messages, anywhere.

## How it works

1. Select text in any app
2. Press **Control + G**
3. A preview panel appears with three modes:
   - **Natural**: casual, like texting a friend
   - **Professional**: for work emails and formal communication
   - **Shorter**: same meaning, fewer words
4. Click a mode to switch, click **Replace** to apply, or **Cancel** to dismiss

Supports English, Chinese, and Chinglish input. Always outputs natural American English.

## Setup

**Requirements:** macOS 13+, Xcode 15+, OpenAI API key

```bash
git clone https://github.com/JaimeYeung/QuickPolish2.git
cd QuickPolish2
open Package.swift
```

In Xcode, press **▶ Run**. On first launch, click the menubar icon and enter your OpenAI API key.

Get an API key at [platform.openai.com](https://platform.openai.com).

## Permissions

macOS will ask for **Accessibility** permission on first run. This is required to read your selected text.

> System Settings → Privacy & Security → Accessibility → toggle on the app

## Menubar

The app lives in your menubar (✦ icon). Click it to set your API key or quit.
