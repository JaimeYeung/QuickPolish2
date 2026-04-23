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

final class CapturingSession: URLSessionProtocol {
    var capturedRequest: URLRequest?
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequest = request
        let json = #"{"choices":[{"message":{"content":"ok"}}]}"#
        return (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
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
            XCTAssertTrue(
                result.text(for: mode).hasPrefix("[error:"),
                "Expected mode \(mode) to have an error-prefixed placeholder, got: \(result.text(for: mode))"
            )
        }
        XCTAssertNotNil(result.error, "All-modes failure should surface a top-level error")
    }

    func test_rewriteAll_includesAuthHeader() async {
        let session = CapturingSession()
        let rewriter = Rewriter(apiKey: "sk-mykey", session: session)
        _ = await rewriter.rewriteAll(text: "test")
        XCTAssertEqual(session.capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-mykey")
    }
}
