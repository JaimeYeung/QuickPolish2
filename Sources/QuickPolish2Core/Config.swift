import Foundation

public final class Config {
    public static let shared = Config()

    private let envFile: URL

    public init(envDirectory: URL? = nil) {
        let dir = envDirectory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".quickpolish")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        envFile = dir.appendingPathComponent(".env.local")
    }

    public var apiKey: String? {
        guard let contents = try? String(contentsOf: envFile, encoding: .utf8) else { return nil }
        for line in contents.components(separatedBy: .newlines) {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespaces) == "OPENAI_API_KEY" {
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    public var hasApiKey: Bool {
        guard let key = apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var envFilePath: String { envFile.path }
}
