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

public enum RewriterError: Error, CustomStringConvertible {
    case apiError(status: Int, message: String)
    case badJSON(String)
    case networkFailure(String)

    public var description: String {
        switch self {
        case .apiError(let status, let message):
            return "API \(status): \(message)"
        case .badJSON(let info):
            return "Bad JSON: \(info)"
        case .networkFailure(let info):
            return "Network: \(info)"
        }
    }
}

public struct Rewriter {
    let apiKey: String
    let model: String
    let session: URLSessionProtocol

    public init(apiKey: String, model: String = "gpt-4o-mini", session: URLSessionProtocol = URLSession.shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    public func rewriteAll(text: String) async -> RewriteResult {
        await withTaskGroup(of: (RewriteMode, Result<String, Error>).self) { group in
            for mode in RewriteMode.allCases {
                group.addTask {
                    do {
                        let text = try await rewrite(text: text, mode: mode)
                        return (mode, .success(text))
                    } catch {
                        return (mode, .failure(error))
                    }
                }
            }
            var result = RewriteResult()
            var firstError: String?
            for await (mode, outcome) in group {
                switch outcome {
                case .success(let text):
                    result.results[mode] = text
                case .failure(let error):
                    let description = (error as? RewriterError)?.description
                        ?? String(describing: error)
                    DebugLog.info("Rewriter \(mode.rawValue) failed: \(description)")
                    result.results[mode] = "[error: \(description)]"
                    if firstError == nil { firstError = description }
                }
            }
            if result.results.values.allSatisfy({ $0.hasPrefix("[error:") }),
               let firstError {
                result.error = firstError
            }
            return result
        }
    }

    private func rewrite(text: String, mode: RewriteMode) async throws -> String {
        guard let promptTemplate = userPrompts[mode] else {
            throw RewriterError.badJSON("missing prompt template for \(mode)")
        }
        let prompt = String(format: promptTemplate, text)
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1000,
            "temperature": 0.7
        ]

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw RewriterError.networkFailure("invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RewriterError.networkFailure(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let preview = String(data: data, encoding: .utf8)?.prefix(200) ?? "<non-utf8>"
            throw RewriterError.badJSON("unparseable (status=\(status)): \(preview)")
        }

        if status < 200 || status >= 300 {
            let apiMessage = (json["error"] as? [String: Any])?["message"] as? String
                ?? String(data: data, encoding: .utf8)?.prefix(200).description
                ?? "unknown"
            throw RewriterError.apiError(status: status, message: apiMessage)
        }

        guard
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            let preview = String(data: data, encoding: .utf8)?.prefix(200) ?? "<non-utf8>"
            throw RewriterError.badJSON("missing choices[].message.content in: \(preview)")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
