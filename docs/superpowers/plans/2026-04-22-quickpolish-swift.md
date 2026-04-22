# QuickPolish Swift Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS background app in Swift that rewrites selected text via OpenAI API when the user presses Control+G, showing a floating non-activating panel so focus never leaves the target app.

**Architecture:** Two SPM targets — `QuickPolish2Core` (library, testable) contains all business logic; `QuickPolish2` (executable) is a thin entry point. AppDelegate owns the menubar icon, hotkey manager, and panel lifecycle. NSPanel with `nonactivatingPanel` style never steals keyboard focus, solving the paste problem entirely.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, AXUIElement, CGEvent, NSEvent, Security (Keychain), URLSession async/await, XCTest

---

## File Map

| File | Target | Responsibility |
|------|--------|----------------|
| `Package.swift` | — | SPM manifest, two targets |
| `Sources/QuickPolish2/main.swift` | Executable | NSApplication entry point |
| `Sources/QuickPolish2Core/Models.swift` | Library | RewriteMode, RewriteResult, PreviewState |
| `Sources/QuickPolish2Core/Config.swift` | Library | KeychainService protocol + Config class |
| `Sources/QuickPolish2Core/Rewriter.swift` | Library | URLSessionProtocol + Rewriter + prompts |
| `Sources/QuickPolish2Core/TextAccessor.swift` | Library | AXUIElement read + CGEvent Cmd+V paste |
| `Sources/QuickPolish2Core/HotkeyManager.swift` | Library | NSEvent global monitor for Ctrl+G |
| `Sources/QuickPolish2Core/PreviewViewModel.swift` | Library | ObservableObject state for the panel |
| `Sources/QuickPolish2Core/PreviewView.swift` | Library | SwiftUI panel UI + glass morphism pills |
| `Sources/QuickPolish2Core/PreviewPanel.swift` | Library | NSPanel subclass, nonactivatingPanel |
| `Sources/QuickPolish2Core/AppDelegate.swift` | Library | NSApplicationDelegate, menubar, orchestration |
| `Tests/QuickPolish2Tests/ModelsTests.swift` | Test | RewriteResult, PreviewViewModel state |
| `Tests/QuickPolish2Tests/ConfigTests.swift` | Test | Config read/write with mock keychain |
| `Tests/QuickPolish2Tests/RewriterTests.swift` | Test | Rewriter with mock URLSession |

---

## Task 1: Project Setup

**Files:**
- Create: `Package.swift`
- Create: `Sources/QuickPolish2/main.swift`
- Create: `Sources/QuickPolish2Core/.gitkeep`
- Create: `Tests/QuickPolish2Tests/.gitkeep`
- Create: `.gitignore`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickPolish2",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "QuickPolish2",
            dependencies: ["QuickPolish2Core"],
            path: "Sources/QuickPolish2"
        ),
        .target(
            name: "QuickPolish2Core",
            path: "Sources/QuickPolish2Core"
        ),
        .testTarget(
            name: "QuickPolish2Tests",
            dependencies: ["QuickPolish2Core"],
            path: "Tests/QuickPolish2Tests"
        )
    ]
)
```

- [ ] **Step 2: Create directory structure**

```bash
mkdir -p Sources/QuickPolish2
mkdir -p Sources/QuickPolish2Core
mkdir -p Tests/QuickPolish2Tests
```

- [ ] **Step 3: Create Sources/QuickPolish2/main.swift**

```swift
import AppKit
import QuickPolish2Core

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 4: Create .gitignore**

```
.DS_Store
.build/
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
```

- [ ] **Step 5: Verify project compiles**

```bash
cd ~/Desktop/QuickPolish2
swift build 2>&1 | head -20
```

Expected: build error about missing AppDelegate (that's fine — confirms Package.swift is valid).

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/ Tests/ .gitignore
git commit -m "chore: Swift SPM project setup"
```

---

## Task 2: Models

**Files:**
- Create: `Sources/QuickPolish2Core/Models.swift`
- Create: `Tests/QuickPolish2Tests/ModelsTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/QuickPolish2Tests/ModelsTests.swift
import XCTest
@testable import QuickPolish2Core

final class ModelsTests: XCTestCase {

    func test_rewriteMode_allCasesCount() {
        XCTAssertEqual(RewriteMode.allCases.count, 3)
    }

    func test_rewriteResult_textForMode_returnsCorrectText() {
        var result = RewriteResult()
        result.results[.natural] = "hey"
        result.results[.professional] = "Dear Sir"
        result.results[.shorter] = "hi"

        XCTAssertEqual(result.text(for: .natural), "hey")
        XCTAssertEqual(result.text(for: .professional), "Dear Sir")
        XCTAssertEqual(result.text(for: .shorter), "hi")
    }

    func test_rewriteResult_textForMode_returnsEmptyWhenMissing() {
        let result = RewriteResult()
        XCTAssertEqual(result.text(for: .natural), "")
    }

    func test_rewriteResult_hasError_falseByDefault() {
        let result = RewriteResult()
        XCTAssertFalse(result.hasError)
    }

    func test_rewriteResult_hasError_trueWhenErrorSet() {
        var result = RewriteResult()
        result.error = "network error"
        XCTAssertTrue(result.hasError)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter ModelsTests 2>&1 | tail -10
```

Expected: `error: no such module 'QuickPolish2Core'`

- [ ] **Step 3: Implement Models.swift**

```swift
// Sources/QuickPolish2Core/Models.swift
import Foundation

public enum RewriteMode: String, CaseIterable, Identifiable {
    case natural = "Natural"
    case professional = "Professional"
    case shorter = "Shorter"

    public var id: String { rawValue }
}

public struct RewriteResult {
    public var results: [RewriteMode: String] = [:]
    public var error: String?

    public init() {}

    public func text(for mode: RewriteMode) -> String {
        results[mode] ?? ""
    }

    public var hasError: Bool { error != nil }
}

public enum PreviewState {
    case loading
    case ready(RewriteResult)
    case error(String)
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter ModelsTests 2>&1 | tail -10
```

Expected: `Test Suite 'ModelsTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickPolish2Core/Models.swift Tests/QuickPolish2Tests/ModelsTests.swift
git commit -m "feat: Models — RewriteMode, RewriteResult, PreviewState"
```

---

## Task 3: Config (Keychain)

**Files:**
- Create: `Sources/QuickPolish2Core/Config.swift`
- Create: `Tests/QuickPolish2Tests/ConfigTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/QuickPolish2Tests/ConfigTests.swift
import XCTest
@testable import QuickPolish2Core

final class MockKeychain: KeychainService {
    var storage: [String: String] = [:]

    func read(key: String) -> String? { storage[key] }
    func write(key: String, value: String) { storage[key] = value }
    func delete(key: String) { storage.removeValue(forKey: key) }
}

final class ConfigTests: XCTestCase {

    func test_hasApiKey_falseWhenNoKeyStored() {
        let config = Config(keychain: MockKeychain())
        XCTAssertFalse(config.hasApiKey)
    }

    func test_hasApiKey_trueAfterKeySet() {
        let config = Config(keychain: MockKeychain())
        config.apiKey = "sk-test"
        XCTAssertTrue(config.hasApiKey)
    }

    func test_apiKey_nilAfterDelete() {
        let config = Config(keychain: MockKeychain())
        config.apiKey = "sk-test"
        config.apiKey = nil
        XCTAssertNil(config.apiKey)
    }

    func test_apiKey_persistsValue() {
        let keychain = MockKeychain()
        let config = Config(keychain: keychain)
        config.apiKey = "sk-abc123"
        XCTAssertEqual(config.apiKey, "sk-abc123")
    }

    func test_hasApiKey_falseForWhitespaceOnly() {
        let config = Config(keychain: MockKeychain())
        config.apiKey = "   "
        XCTAssertFalse(config.hasApiKey)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter ConfigTests 2>&1 | tail -5
```

Expected: compile error — `KeychainService` not found.

- [ ] **Step 3: Implement Config.swift**

```swift
// Sources/QuickPolish2Core/Config.swift
import Foundation
import Security

public protocol KeychainService {
    func read(key: String) -> String?
    func write(key: String, value: String)
    func delete(key: String)
}

public final class SystemKeychain: KeychainService {
    public init() {}

    public func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func write(key: String, value: String) {
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    public func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public final class Config {
    public static let shared = Config()

    private let keychain: KeychainService
    private let apiKeyName = "com.quickpolish.openai-key"

    public init(keychain: KeychainService = SystemKeychain()) {
        self.keychain = keychain
    }

    public var apiKey: String? {
        get { keychain.read(key: apiKeyName) }
        set {
            if let value = newValue {
                keychain.write(key: apiKeyName, value: value)
            } else {
                keychain.delete(key: apiKeyName)
            }
        }
    }

    public var hasApiKey: Bool {
        guard let key = apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter ConfigTests 2>&1 | tail -5
```

Expected: `Test Suite 'ConfigTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickPolish2Core/Config.swift Tests/QuickPolish2Tests/ConfigTests.swift
git commit -m "feat: Config — Keychain-backed API key storage"
```

---

## Task 4: Rewriter

**Files:**
- Create: `Sources/QuickPolish2Core/Rewriter.swift`
- Create: `Tests/QuickPolish2Tests/RewriterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/QuickPolish2Tests/RewriterTests.swift
import XCTest
@testable import QuickPolish2Core

final class MockURLSession: URLSessionProtocol {
    let responseText: String
    var shouldFail: Bool

    init(responseText: String, shouldFail: Bool = false) {
        self.responseText = responseText
        self.shouldFail = shouldFail
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if shouldFail { throw URLError(.networkConnectionLost) }
        let json = """
        {"choices":[{"message":{"content":"\(responseText)"}}]}
        """
        let data = Data(json.utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}

final class RewriterTests: XCTestCase {

    func test_rewriteAll_returnsResultsForAllModes() async {
        let rewriter = Rewriter(apiKey: "sk-test", session: MockURLSession(responseText: "fixed"))
        let result = await rewriter.rewriteAll(text: "hello world")

        XCTAssertEqual(result.results.count, 3)
        XCTAssertEqual(result.text(for: .natural), "fixed")
        XCTAssertEqual(result.text(for: .professional), "fixed")
        XCTAssertEqual(result.text(for: .shorter), "fixed")
    }

    func test_rewriteAll_onNetworkError_setsErrorResult() async {
        let rewriter = Rewriter(apiKey: "sk-test", session: MockURLSession(responseText: "", shouldFail: true))
        let result = await rewriter.rewriteAll(text: "hello")

        for mode in RewriteMode.allCases {
            XCTAssertEqual(result.text(for: mode), "[error]")
        }
    }

    func test_rewriteAll_includesAuthHeader() async {
        var capturedRequest: URLRequest?
        class CapturingSession: URLSessionProtocol {
            var request: URLRequest?
            func data(for request: URLRequest) async throws -> (Data, URLResponse) {
                self.request = request
                let json = #"{"choices":[{"message":{"content":"ok"}}]}"#
                return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
        }
        let session = CapturingSession()
        let rewriter = Rewriter(apiKey: "sk-mykey", session: session)
        _ = await rewriter.rewriteAll(text: "test")
        XCTAssertEqual(session.request?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-mykey")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter RewriterTests 2>&1 | tail -5
```

Expected: compile error — `URLSessionProtocol` not found.

- [ ] **Step 3: Implement Rewriter.swift**

```swift
// Sources/QuickPolish2Core/Rewriter.swift
import Foundation

public protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

private let systemPrompt = """
You are a text rewriter. The user will give you text that may be in English, Chinese, or a mix of both.

Your job: understand the intended meaning and express it in natural American English.

Rules:
- Always output English only
- Do not translate literally — understand the intent and express it the way a native speaker would
- Do not add meaning that wasn't there
- Do not sound like AI. No "Certainly!", no "I hope this helps", no filler
- Return ONLY the rewritten text, nothing else. No quotes, no explanation.
"""

private let userPrompts: [RewriteMode: String] = [
    .natural: "Rewrite this in casual, natural American English — the way you'd text a friend. Keep it chill and real.\n\nText: %@",
    .professional: "Rewrite this for a professional email. Sound confident, direct, and warm — like a real person, not a robot. No corporate filler: no 'I hope this email finds you well', no 'please don't hesitate to reach out', no 'as per my previous email'.\n\nText: %@",
    .shorter: "Rewrite this in natural American English, then trim it down. Keep the meaning and tone. Remove redundancy without losing the point.\n\nText: %@"
]

public struct Rewriter {
    let apiKey: String
    let model: String
    let session: URLSessionProtocol

    public init(apiKey: String, model: String = "gpt-4o", session: URLSessionProtocol = URLSession.shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    public func rewriteAll(text: String) async -> RewriteResult {
        await withTaskGroup(of: (RewriteMode, String).self) { group in
            for mode in RewriteMode.allCases {
                group.addTask {
                    let result = (try? await rewrite(text: text, mode: mode)) ?? "[error]"
                    return (mode, result)
                }
            }
            var result = RewriteResult()
            for await (mode, text) in group {
                result.results[mode] = text
            }
            return result
        }
    }

    private func rewrite(text: String, mode: RewriteMode) async throws -> String {
        let prompt = String(format: userPrompts[mode]!, text)
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1000,
            "temperature": 0.7
        ]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let choices = json["choices"] as! [[String: Any]]
        let message = choices[0]["message"] as! [String: Any]
        return (message["content"] as! String).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter RewriterTests 2>&1 | tail -5
```

Expected: `Test Suite 'RewriterTests' passed`

- [ ] **Step 5: Run all tests**

```bash
swift test 2>&1 | tail -10
```

Expected: all tests pass (ModelsTests + ConfigTests + RewriterTests).

- [ ] **Step 6: Commit**

```bash
git add Sources/QuickPolish2Core/Rewriter.swift Tests/QuickPolish2Tests/RewriterTests.swift
git commit -m "feat: Rewriter — parallel OpenAI API calls with correct prompts"
```

---

## Task 5: TextAccessor

**Files:**
- Create: `Sources/QuickPolish2Core/TextAccessor.swift`

No unit tests — wraps AXUIElement and CGEvent system calls. Tested manually during integration.

- [ ] **Step 1: Implement TextAccessor.swift**

```swift
// Sources/QuickPolish2Core/TextAccessor.swift
import AppKit
import ApplicationServices

public struct TextAccessor {

    /// Reads the currently selected text in the focused element via AXUIElement.
    /// Returns nil if no text is selected or Accessibility permission is not granted.
    public static func getSelectedText() -> String? {
        let system = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else { return nil }

        let focused = focusedRef as! AXUIElement
        var selectedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedRef
        ) == .success,
        let text = selectedRef as? String,
        !text.isEmpty else { return nil }

        return text
    }

    /// Writes text to the clipboard and simulates Cmd+V.
    /// Because our NSPanel never steals keyboard focus, the target element
    /// remains focused and receives the paste event.
    public static func pasteText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        // Virtual key 0x09 = 'v'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
```

- [ ] **Step 2: Verify project builds**

```bash
swift build 2>&1 | tail -5
```

Expected: builds successfully (may warn about AppDelegate missing — fine for now).

- [ ] **Step 3: Commit**

```bash
git add Sources/QuickPolish2Core/TextAccessor.swift
git commit -m "feat: TextAccessor — AXUIElement read + CGEvent paste"
```

---

## Task 6: HotkeyManager

**Files:**
- Create: `Sources/QuickPolish2Core/HotkeyManager.swift`

No unit tests — wraps NSEvent system calls.

- [ ] **Step 1: Implement HotkeyManager.swift**

```swift
// Sources/QuickPolish2Core/HotkeyManager.swift
import AppKit

public final class HotkeyManager {
    public var onHotkey: (() -> Void)?
    private var monitor: Any?

    public init() {}

    public func startListening() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Control+G: keyCode 5, only Control modifier (no Cmd/Option/Shift)
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
```

- [ ] **Step 2: Commit**

```bash
git add Sources/QuickPolish2Core/HotkeyManager.swift
git commit -m "feat: HotkeyManager — NSEvent global monitor for Ctrl+G"
```

---

## Task 7: PreviewViewModel + PreviewView

**Files:**
- Create: `Sources/QuickPolish2Core/PreviewViewModel.swift`
- Create: `Sources/QuickPolish2Core/PreviewView.swift`
- Modify: `Tests/QuickPolish2Tests/ModelsTests.swift` (add ViewModel tests)

- [ ] **Step 1: Add ViewModel tests to ModelsTests.swift**

Add these test cases to the existing `ModelsTests` class:

```swift
func test_previewViewModel_initialStateIsLoading() {
    let vm = PreviewViewModel()
    XCTAssertTrue(vm.isLoading)
    XCTAssertEqual(vm.selectedMode, .natural)
}

func test_previewViewModel_currentTextEmptyWhileLoading() {
    let vm = PreviewViewModel()
    XCTAssertEqual(vm.currentText, "")
}

func test_previewViewModel_currentTextAfterReady() {
    let vm = PreviewViewModel()
    var result = RewriteResult()
    result.results[.natural] = "hey"
    vm.state = .ready(result)
    XCTAssertEqual(vm.currentText, "hey")
    XCTAssertFalse(vm.isLoading)
}

func test_previewViewModel_currentTextChangesWithMode() {
    let vm = PreviewViewModel()
    var result = RewriteResult()
    result.results[.natural] = "hey"
    result.results[.professional] = "Dear"
    vm.state = .ready(result)
    vm.selectedMode = .professional
    XCTAssertEqual(vm.currentText, "Dear")
}

func test_previewViewModel_hasError_falseOnNormalResult() {
    let vm = PreviewViewModel()
    vm.state = .ready(RewriteResult())
    XCTAssertFalse(vm.hasError)
}

func test_previewViewModel_hasError_trueOnErrorState() {
    let vm = PreviewViewModel()
    vm.state = .error("network failed")
    XCTAssertTrue(vm.hasError)
}
```

- [ ] **Step 2: Run tests to verify new ones fail**

```bash
swift test --filter ModelsTests 2>&1 | tail -10
```

Expected: compile error — `PreviewViewModel` not found.

- [ ] **Step 3: Implement PreviewViewModel.swift**

```swift
// Sources/QuickPolish2Core/PreviewViewModel.swift
import Foundation
import Combine

public final class PreviewViewModel: ObservableObject {
    @Published public var state: PreviewState = .loading
    @Published public var selectedMode: RewriteMode = .natural

    public var onReplace: ((String) -> Void)?
    public var onCancel: (() -> Void)?

    public init() {}

    public var currentText: String {
        guard case .ready(let result) = state else { return "" }
        return result.text(for: selectedMode)
    }

    public var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public var hasError: Bool {
        switch state {
        case .error: return true
        case .ready(let r): return r.hasError
        default: return false
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter ModelsTests 2>&1 | tail -10
```

Expected: all ModelsTests pass.

- [ ] **Step 5: Implement PreviewView.swift**

```swift
// Sources/QuickPolish2Core/PreviewView.swift
import SwiftUI

public struct PreviewView: View {
    @ObservedObject public var viewModel: PreviewViewModel

    public init(viewModel: PreviewViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.45))
                )

            VStack(spacing: 0) {
                titleBar
                Divider().overlay(Color.white.opacity(0.08))
                contentArea
                Divider().overlay(Color.white.opacity(0.08))
                modeSelector
                Divider().overlay(Color.white.opacity(0.08))
                actionBar
            }
        }
        .frame(width: 460)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
        .environment(\.colorScheme, .dark)
    }

    private var titleBar: some View {
        HStack {
            Text("✦ QuickPolish")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var contentArea: some View {
        Group {
            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.75)
                    Text("Rewriting…")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollView {
                    Text(viewModel.currentText)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 140)
            }
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 6) {
            ForEach(RewriteMode.allCases) { mode in
                ModeButton(
                    title: mode.rawValue,
                    isSelected: viewModel.selectedMode == mode,
                    isEnabled: !viewModel.isLoading
                ) {
                    viewModel.selectedMode = mode
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var actionBar: some View {
        HStack {
            Button("Cancel") { viewModel.onCancel?() }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.horizontal, 4)

            Spacer()

            Button("Replace") { viewModel.onReplace?(viewModel.currentText) }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 13, weight: .medium))
                .disabled(viewModel.isLoading || viewModel.hasError)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ModeButton: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected ? Color.accentColor : Color.white.opacity(isEnabled ? 0.5 : 0.25)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isSelected
                                ? Color.accentColor.opacity(0.18)
                                : Color.white.opacity(0.06)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    isSelected
                                        ? Color.accentColor.opacity(0.5)
                                        : Color.white.opacity(0.12),
                                    lineWidth: 0.5
                                )
                        )
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
```

- [ ] **Step 6: Build to verify no compile errors**

```bash
swift build 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add Sources/QuickPolish2Core/PreviewViewModel.swift Sources/QuickPolish2Core/PreviewView.swift Tests/QuickPolish2Tests/ModelsTests.swift
git commit -m "feat: PreviewViewModel + PreviewView with glass morphism mode pills"
```

---

## Task 8: PreviewPanel

**Files:**
- Create: `Sources/QuickPolish2Core/PreviewPanel.swift`

- [ ] **Step 1: Implement PreviewPanel.swift**

```swift
// Sources/QuickPolish2Core/PreviewPanel.swift
import AppKit
import SwiftUI

public final class PreviewPanel: NSPanel {

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false  // SwiftUI view provides its own shadow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // Never steal keyboard focus — this is the key to making paste work
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public func showCentered() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
        orderFront(nil)
    }

    public func updateContent(viewModel: PreviewViewModel) {
        let hostingView = NSHostingView(rootView: PreviewView(viewModel: viewModel))
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        contentView = hostingView
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/QuickPolish2Core/PreviewPanel.swift
git commit -m "feat: PreviewPanel — NSPanel nonactivatingPanel, never steals focus"
```

---

## Task 9: AppDelegate

**Files:**
- Create: `Sources/QuickPolish2Core/AppDelegate.swift`

- [ ] **Step 1: Implement AppDelegate.swift**

```swift
// Sources/QuickPolish2Core/AppDelegate.swift
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
        setupMenubar()
        setupHotkey()
        checkAccessibilityPermission()
    }

    // MARK: - Menubar

    private func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let button = statusItem?.button
        button?.image = NSImage(systemSymbolName: "pencil.and.sparkles", accessibilityDescription: "QuickPolish")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Set API Key…", action: #selector(showApiKeyInput), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit QuickPolish", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func showApiKeyInput() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "OpenAI API Key"
        alert.informativeText = "Enter your OpenAI API key. It's stored securely in your Keychain."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.placeholderString = "sk-..."
        input.stringValue = Config.shared.apiKey ?? ""
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = input.stringValue.trimmingCharacters(in: .whitespaces)
            Config.shared.apiKey = trimmed.isEmpty ? nil : trimmed
        }
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyManager.onHotkey = { [weak self] in
            self?.handleHotkey()
        }
        hotkeyManager.startListening()
    }

    private func handleHotkey() {
        guard Config.shared.hasApiKey else {
            showApiKeyInput()
            return
        }
        guard let text = TextAccessor.getSelectedText() else { return }

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
        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }
}
```

- [ ] **Step 2: Build to verify everything compiles**

```bash
swift build 2>&1 | tail -10
```

Expected: build succeeds with no errors.

- [ ] **Step 3: Run full test suite**

```bash
swift test 2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/QuickPolish2Core/AppDelegate.swift
git commit -m "feat: AppDelegate — menubar, hotkey orchestration, panel lifecycle"
```

---

## Task 10: README + Manual Integration Test

**Files:**
- Create: `README.md`
- Create: `.gitignore` update

- [ ] **Step 1: Create README.md**

```markdown
# QuickPolish

Fix grammar and rewrite selected text using AI — without leaving your app.

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
open Package.swift   # opens in Xcode
```

In Xcode, press **▶ Run**. On first launch, click the menubar icon (✦) and enter your OpenAI API key.

Get an API key at [platform.openai.com](https://platform.openai.com).

## Permissions

macOS will ask for **Accessibility** permission on first run. This is required to read your selected text.

> System Settings → Privacy & Security → Accessibility → toggle on the app

## Running in background

The app lives in your menubar. It starts automatically when you run it from Xcode. To quit, click the menubar icon → Quit QuickPolish.
```

- [ ] **Step 2: Open in Xcode and run manually**

```bash
open Package.swift
```

In Xcode:
1. Select the `QuickPolish2` scheme
2. Press ▶ Run
3. Grant Accessibility permission when prompted
4. Click menubar icon → Set API Key → enter OpenAI key

- [ ] **Step 3: Manual integration test — Gmail**

1. Open Gmail in Chrome, start composing an email
2. Type: `i think this is good idea we should try`
3. Select the text
4. Press Control+G
5. Verify panel appears with Natural result
6. Click **Professional** — verify result changes
7. Click **Replace** — verify text in Gmail compose is replaced
8. Repeat with Esc/Cancel — verify original text unchanged

- [ ] **Step 4: Manual integration test — Chinglish**

1. In any text field, type: `我觉得这个 approach 很好，我们可以 try 一下`
2. Select and press Control+G
3. Verify Natural sounds like a real English text message
4. Verify Professional sounds like a confident email sentence

- [ ] **Step 5: Commit and push**

```bash
git add README.md
git commit -m "docs: README with setup instructions"
git push
```

---

## Permissions Note

On first run, macOS prompts for **Accessibility** permission. Without it, `AXUIElementCopyAttributeValue` returns `.apiDisabled` and `getSelectedText()` returns nil — the app silently does nothing on hotkey. Direct the user to:

> System Settings → Privacy & Security → Accessibility → add the QuickPolish app
