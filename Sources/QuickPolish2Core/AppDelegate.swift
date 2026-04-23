import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var previewPanel: PreviewPanel?
    private var hintPanel: HintPanel?
    private var previewViewModel = PreviewViewModel()
    private let hotkeyManager = HotkeyManager()

    public override init() {}

    public func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLog.info("app launched — pid=\(getpid())")
        setupMenubar()
        setupHotkey()
    }

    // MARK: - Menubar

    private func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(
            systemSymbolName: "pencil.and.sparkles",
            accessibilityDescription: "QuickPolish"
        )

        let menu = NSMenu()

        let hintItem = NSMenuItem(
            title: "Copy text, then press ⌃G",
            action: nil,
            keyEquivalent: ""
        )
        hintItem.isEnabled = false
        menu.addItem(hintItem)

        menu.addItem(.separator())

        let apiItem = NSMenuItem(
            title: "Set API Key…",
            action: #selector(showApiKeyInput),
            keyEquivalent: ""
        )
        apiItem.target = self
        menu.addItem(apiItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit QuickPolish",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
    }

    @objc private func showApiKeyInput() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "API Key Not Found"
        alert.informativeText = """
        Add your OpenAI API key to:
        \(Config.shared.envFilePath)

        Format:
        OPENAI_API_KEY=sk-...
        """
        alert.addButton(withTitle: "Open File")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let path = Config.shared.envFilePath
            if !FileManager.default.fileExists(atPath: path) {
                try? "OPENAI_API_KEY=sk-your-key-here".write(
                    toFile: path, atomically: true, encoding: .utf8
                )
            }
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyManager.onHotkey = { [weak self] in
            self?.handleHotkey()
        }
        hotkeyManager.startListening()
    }

    private func handleHotkey() {
        DebugLog.info("hotkey fired")

        guard Config.shared.hasApiKey else {
            showApiKeyInput()
            return
        }

        guard let text = TextAccessor.getClipboardText() else {
            DebugLog.info("clipboard has no text — showing hint")
            showHint(
                title: "Clipboard is empty",
                subtitle: "Copy text with ⌘C first, then press ⌃G."
            )
            return
        }

        showPreview(for: text)
    }

    // MARK: - Panels

    private func showHint(title: String, subtitle: String) {
        if hintPanel == nil {
            hintPanel = HintPanel()
        }
        hintPanel?.show(title: title, subtitle: subtitle)
    }

    private func showPreview(for text: String) {
        let vm = PreviewViewModel()
        previewViewModel = vm

        if previewPanel == nil {
            previewPanel = PreviewPanel()
        }
        previewPanel?.updateContent(viewModel: vm)

        vm.onReplace = { [weak self] result in
            self?.previewPanel?.orderOut(nil)
            TextAccessor.pasteText(result)
        }
        vm.onCancel = { [weak self] in
            self?.previewPanel?.orderOut(nil)
        }

        previewPanel?.showCentered()

        guard let apiKey = Config.shared.apiKey else { return }
        Task {
            let rewriter = Rewriter(apiKey: apiKey)
            let result = await rewriter.rewriteAll(text: text)
            await MainActor.run {
                vm.state = .ready(result)
            }
        }
    }
}
