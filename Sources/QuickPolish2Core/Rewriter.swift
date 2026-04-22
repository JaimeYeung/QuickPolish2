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
