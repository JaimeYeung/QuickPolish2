import AppKit
import SwiftUI
import ApplicationServices

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var previewPanel: PreviewPanel?
    private var previewViewModel = PreviewViewModel()
    private let hotkeyManager = HotkeyManager()

    public override init() {}

    public func applicationDidFinishLaunching(_ notification: Notification) {
        print("[QP] app launched")
        setupMenubar()
        setupHotkey()
        checkAccessibilityPermission()
        print("[QP] hasApiKey=\(Config.shared.hasApiKey) apiKey=\(Config.shared.apiKey?.prefix(10) ?? "nil")")
    }

    // MARK: - Menubar

    private func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(
            systemSymbolName: "pencil.and.sparkles",
            accessibilityDescription: "QuickPolish"
        )

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Set API Key…", action: #selector(showApiKeyInput), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit QuickPolish", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func showApiKeyInput() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "API Key Not Found"
        alert.informativeText = "Add your OpenAI API key to:\n\(Config.shared.envFilePath)\n\nFormat:\nOPENAI_API_KEY=sk-..."
        alert.addButton(withTitle: "Open File")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let path = Config.shared.envFilePath
            if !FileManager.default.fileExists(atPath: path) {
                try? "OPENAI_API_KEY=sk-your-key-here".write(toFile: path, atomically: true, encoding: .utf8)
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
        print("[QP] hotkey listener started")
    }

    private func handleHotkey() {
        print("[QP] hotkey fired!")
        guard Config.shared.hasApiKey else {
            print("[QP] no API key")
            showApiKeyInput()
            return
        }
        let text = TextAccessor.getSelectedText()
        print("[QP] selected text: \(text?.prefix(50) ?? "nil")")
        guard let text else { return }
        showPreview(for: text)
    }

    // MARK: - Panel

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

        Task {
            let rewriter = Rewriter(apiKey: Config.shared.apiKey!)
            let result = await rewriter.rewriteAll(text: text)
            await MainActor.run {
                vm.state = .ready(result)
            }
        }
    }

    // MARK: - Accessibility

    private func checkAccessibilityPermission() {
        if AXIsProcessTrusted() {
            print("[QP] Accessibility: granted")
        } else {
            print("[QP] Accessibility: NOT granted — opening System Settings")
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }
}
