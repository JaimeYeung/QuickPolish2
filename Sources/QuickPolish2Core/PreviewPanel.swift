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

    // Never steal keyboard focus — this is what makes paste work reliably
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
