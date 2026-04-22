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
