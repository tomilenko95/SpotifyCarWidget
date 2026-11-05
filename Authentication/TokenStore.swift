import Foundation
import Security

struct OAuthTokens: Codable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

protocol TokenStoring: Sendable {
    func read() throws -> OAuthTokens?
    func write(_ tokens: OAuthTokens) throws
    func clear() throws
}

struct KeychainTokenStore: TokenStoring {
    var group: String? = AppConfiguration.current.keychainGroup
    private var query: [String: Any] { get throws {
        var result: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "SpotifyCarWidget.OAuth", kSecAttrAccount as String: "spotify"]
        if AppConfiguration.personalSpotify {
            // Access-group discovery failures must propagate, rather than silently using a private item.
            result[kSecAttrAccessGroup as String] = try SharedKeychain.accessGroup
        } else if !AppConfiguration.personalDemo, let group, !group.isEmpty { result[kSecAttrAccessGroup as String] = group }
        return result
    } }
    func read() throws -> OAuthTokens? {
        var q = try query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw OAuthError.keychain(status) }
        return try JSONDecoder().decode(OAuthTokens.self, from: data)
    }
    func write(_ tokens: OAuthTokens) throws {
        let query = try self.query
        let attributes: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(tokens),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let inserted = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard inserted == errSecSuccess else { throw OAuthError.keychain(inserted) }
        } else if status != errSecSuccess { throw OAuthError.keychain(status) }
    }
    func clear() throws {
        let status = SecItemDelete(try query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw OAuthError.keychain(status) }
    }
}
