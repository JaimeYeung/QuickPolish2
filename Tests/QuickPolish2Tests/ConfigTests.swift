import XCTest
@testable import QuickPolish2Core

final class ConfigTests: XCTestCase {

    func test_hasApiKey_falseWhenFileDoesNotExist() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let config = Config(envDirectory: dir)
        XCTAssertFalse(config.hasApiKey)
    }

    func test_apiKey_parsedFromEnvFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(".env.local")
        try "OPENAI_API_KEY=sk-test123".write(to: file, atomically: true, encoding: .utf8)

        let config = Config(envDirectory: dir)
        XCTAssertEqual(config.apiKey, "sk-test123")
        XCTAssertTrue(config.hasApiKey)
    }

    func test_apiKey_nilWhenKeyMissingFromFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(".env.local")
        try "OTHER_VAR=hello".write(to: file, atomically: true, encoding: .utf8)

        let config = Config(envDirectory: dir)
        XCTAssertNil(config.apiKey)
    }

    func test_apiKey_handlesWhitespace() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(".env.local")
        try "OPENAI_API_KEY=  sk-abc  ".write(to: file, atomically: true, encoding: .utf8)

        let config = Config(envDirectory: dir)
        XCTAssertEqual(config.apiKey, "sk-abc")
    }
}
