# QuickPolish

Writing in English takes extra effort when it's not your first language. You know what you want to say, but getting it to sound right takes time. And fixing it usually means jumping to another app, copy-pasting, then switching back.

QuickPolish cuts out all of that. Copy any text, press a hotkey, and get a polished version in seconds without leaving what you're working on. Works in any macOS app: Gmail, Notion, Slack, Messages, anywhere.

## How it works

1. Select text in any app and press **⌘C**
2. Press **⌃G** (Control + G)
3. A preview panel appears with three modes:
   - **Natural**: casual, like texting a friend
   - **Professional**: for work emails and formal communication
   - **Shorter**: same meaning, fewer words
4. Click a mode to switch, click **Replace** to apply, or **Cancel** to dismiss

Supports English, Chinese, and Chinglish input. Always outputs natural American English.

> The ⌘C → ⌃G flow is deliberate: reading from the clipboard is 100% reliable across every app (Chrome, Notion, Electron, terminals, web text boxes), while the old "grab the selection directly" approach silently failed in many of them.

## Setup

**Requirements:** macOS 13+, Swift 5.9+, OpenAI API key

```bash
git clone https://github.com/JaimeYeung/QuickPolish2.git
cd QuickPolish2
```

**1. Add your API key:**

```bash
mkdir -p ~/.quickpolish
echo "OPENAI_API_KEY=sk-your-key-here" > ~/.quickpolish/.env.local
```

Get a key at [platform.openai.com](https://platform.openai.com).

**2. One-time signing setup** (so macOS permissions survive across rebuilds):

```bash
./scripts/setup-signing.sh
```

This creates a self-signed code-signing certificate in your login keychain. macOS ties Accessibility / Input Monitoring grants to the binary's code signature — without a stable identity, every rebuild invalidates the grant and you'd have to re-authorize constantly.

**3. Build and run:**

```bash
./scripts/run.sh
```

This compiles, signs with your local cert, kills any previous instance, and relaunches. The QuickPolish icon (✦) appears in the menubar.

## Permissions

On first launch, macOS may prompt for **Input Monitoring** (needed to paste via simulated ⌘V). Grant it once:

> System Settings → Privacy & Security → Input Monitoring → toggle on QuickPolish2

Thanks to stable signing, you only have to do this once — future `scripts/run.sh` invocations reuse the grant.

## Menubar

The app lives in your menubar. Click the ✦ icon to set your API key or quit.

## Logs

```bash
tail -f ~/.quickpolish/quickpolish.log
```

## Tests

```bash
swift test
```
