import Foundation
import Security

public protocol KeychainService {
    func read(key: String) -> String?
    func write(key: String, value: String)
    func delete(key: String)
}

public final class SystemKeychain: KeychainService {
    public init() {}

    public func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func write(key: String, value: String) {
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    public func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public final class Config {
    public static let shared = Config()

    private let keychain: KeychainService
    private let apiKeyName = "com.quickpolish.openai-key"

    public init(keychain: KeychainService = SystemKeychain()) {
        self.keychain = keychain
    }

    public var apiKey: String? {
        get { keychain.read(key: apiKeyName) }
        set {
            if let value = newValue {
                keychain.write(key: apiKeyName, value: value)
            } else {
                keychain.delete(key: apiKeyName)
            }
        }
    }

    public var hasApiKey: Bool {
        guard let key = apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
