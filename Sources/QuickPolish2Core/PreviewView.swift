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
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.12),
                                    lineWidth: 0.5
                                )
                        )
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
