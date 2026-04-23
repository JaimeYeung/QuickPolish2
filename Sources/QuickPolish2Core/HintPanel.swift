import AppKit
import SwiftUI

/// Small non-activating panel that floats a short message near the top of the
/// screen, then fades away. Used for "empty clipboard" style feedback —
/// lightweight, no interaction required.
public final class HintPanel: NSPanel {

    private var dismissTimer: Timer?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 72),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public func show(title: String, subtitle: String, duration: TimeInterval = 2.4) {
        let view = NSHostingView(rootView: HintView(title: title, subtitle: subtitle))
        view.frame = NSRect(origin: .zero, size: frame.size)
        contentView = view

        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let x = vf.midX - frame.width / 2
        let y = vf.maxY - frame.height - 80
        setFrameOrigin(NSPoint(x: x, y: y))

        alphaValue = 0
        orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            animator().alphaValue = 1
        }

        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    private func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }
}

private struct HintView: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
        .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 8)
        .environment(\.colorScheme, .dark)
        .frame(width: 380, height: 72)
    }
}
