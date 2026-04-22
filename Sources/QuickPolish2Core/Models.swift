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
