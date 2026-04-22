import XCTest
@testable import QuickPolish2Core

final class MockKeychain: KeychainService {
    var storage: [String: String] = [:]
    func read(key: String) -> String? { storage[key] }
    func write(key: String, value: String) { storage[key] = value }
    func delete(key: String) { storage.removeValue(forKey: key) }
}

final class ConfigTests: XCTestCase {

    func test_hasApiKey_falseWhenNoKeyStored() {
        let config = Config(keychain: MockKeychain())
        XCTAssertFalse(config.hasApiKey)
    }

    func test_hasApiKey_trueAfterKeySet() {
        let config = Config(keychain: MockKeychain())
        config.apiKey = "sk-test"
        XCTAssertTrue(config.hasApiKey)
    }

    func test_apiKey_nilAfterDelete() {
        let config = Config(keychain: MockKeychain())
        config.apiKey = "sk-test"
        config.apiKey = nil
        XCTAssertNil(config.apiKey)
    }

    func test_apiKey_persistsValue() {
        let config = Config(keychain: MockKeychain())
        config.apiKey = "sk-abc123"
        XCTAssertEqual(config.apiKey, "sk-abc123")
    }

    func test_hasApiKey_falseForWhitespaceOnly() {
        let config = Config(keychain: MockKeychain())
        config.apiKey = "   "
        XCTAssertFalse(config.hasApiKey)
    }
}
