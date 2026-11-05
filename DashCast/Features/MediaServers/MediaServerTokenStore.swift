import Foundation
import Security

/// Storage for media-server access tokens. Production uses the Keychain;
/// tests inject `InMemoryMediaServerTokenStore`.
public protocol MediaServerTokenStore: AnyObject {
    func token(for accountID: UUID) -> String?
    @discardableResult func setToken(_ token: String, for accountID: UUID) -> Bool
    func removeToken(for accountID: UUID)
}

/// Keeps access tokens in the iOS Keychain (never UserDefaults).
public final class KeychainMediaServerTokenStore: MediaServerTokenStore {
    public static let shared = KeychainMediaServerTokenStore()

    private let service: String

    public init(service: String = "com.xanderco.dashcast.mediaserver") {
        self.service = service
    }

    private func baseQuery(_ accountID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString
        ]
    }

    public func token(for accountID: UUID) -> String? {
        var query = baseQuery(accountID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public func setToken(_ token: String, for accountID: UUID) -> Bool {
        let data = Data(token.utf8)
        let query = baseQuery(accountID)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound {
            var add = query
            add.merge(attributes) { _, new in new }
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    public func removeToken(for accountID: UUID) {
        SecItemDelete(baseQuery(accountID) as CFDictionary)
    }
}

/// Non-persistent token store for tests and previews.
public final class InMemoryMediaServerTokenStore: MediaServerTokenStore {
    private var tokens: [UUID: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func token(for accountID: UUID) -> String? {
        lock.lock(); defer { lock.unlock() }
        return tokens[accountID]
    }

    @discardableResult
    public func setToken(_ token: String, for accountID: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        tokens[accountID] = token
        return true
    }

    public func removeToken(for accountID: UUID) {
        lock.lock(); defer { lock.unlock() }
        tokens[accountID] = nil
    }
}
