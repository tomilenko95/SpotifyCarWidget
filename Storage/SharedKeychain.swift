import Foundation
import Security

/// Small shared records only. Artwork stays in each process's bounded local file cache.
struct SharedKeychain: Sendable {
    static let groupSuffix = "com.carwidget.shared"
    private static let prefixDiscovery = PrefixDiscovery()
    static var accessGroup: String { get throws { try prefixDiscovery.prefix() + "." + groupSuffix } }

    private func query(_ account: String, owner: String? = nil) throws -> [String: Any] {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CarWidget.Shared.v1", kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: try Self.accessGroup]
        if let owner { query[kSecAttrGeneric as String] = Data(owner.utf8) }
        return query
    }
    func read(_ account: String) throws -> Data? {
        var query = try query(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw OAuthError.keychain(status) }
        return data
    }
    func write(_ data: Data, account: String) throws {
        let query = try query(account)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let inserted = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard inserted == errSecSuccess else { throw OAuthError.keychain(inserted) }
        } else if status != errSecSuccess { throw OAuthError.keychain(status) }
    }
    func remove(_ account: String, owner: String? = nil) throws {
        let status = SecItemDelete(try query(account, owner: owner) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw OAuthError.keychain(status) }
    }
    func acquireLease(_ lease: SharedLeaseRecord) throws -> Bool {
        var attributes = try query("playback-lease", owner: lease.owner)
        attributes[kSecValueData as String] = try JSONEncoder().encode(lease)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem { return false }
        guard status == errSecSuccess else { throw OAuthError.keychain(status) }
        return true
    }
    func withLease<T>(_ operation: () async throws -> T) async throws -> T {
        let deadline = Date().addingTimeInterval(6)
        let lease = SharedLeaseRecord(owner: UUID().uuidString, expiresAt: Date().addingTimeInterval(120))
        while try !acquireLease(lease) {
            try Task.checkCancellation()
            if let data = try read("playback-lease"), let previous = try? JSONDecoder().decode(SharedLeaseRecord.self, from: data),
               previous.isExpired(at: Date()) {
                // Generic attribute matches this owner only: cannot remove a newer owner's lease.
                try remove("playback-lease", owner: previous.owner)
            }
            guard Date() < deadline else { throw APIError.busy }
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        defer { try? remove("playback-lease", owner: lease.owner) }
        try Task.checkCancellation()
        return try await operation()
    }
}

struct SharedLeaseRecord: Codable, Equatable, Sendable {
    let owner: String
    let expiresAt: Date
    func isExpired(at date: Date) -> Bool { date >= expiresAt }
}

private final class PrefixDiscovery: @unchecked Sendable {
    private let lock = NSLock()
    private var cached: String?
    func prefix() throws -> String {
        lock.lock(); defer { lock.unlock() }
        if let cached { return cached }
        // Ask Security for our actual signed access group; never guess a sideloaded bundle prefix.
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "CarWidget.PrefixProbe." + UUID().uuidString,
            kSecAttrAccount as String: "probe"]
        var attributes = query
        attributes[kSecValueData as String] = Data("prefix-probe".utf8)
        attributes[kSecReturnAttributes as String] = true
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        var result: CFTypeRef?
        let status = SecItemAdd(attributes as CFDictionary, &result)
        guard status == errSecSuccess else { throw OAuthError.keychain(status) }
        defer { SecItemDelete(query as CFDictionary) }
        guard let returned = result as? [String: Any], let group = returned[kSecAttrAccessGroup as String] as? String,
              let prefix = group.split(separator: ".").first, prefix.count == 10,
              prefix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { throw APIError.storage }
        let value = String(prefix)
        cached = value
        return value
    }
}

enum WidgetConnectionCheck {
    struct Check: Codable { let id: UUID; let requestedAt: Date; var acknowledgedAt: Date? }
    static func request() throws {
        try SharedKeychain().write(JSONEncoder().encode(Check(id: UUID(), requestedAt: Date())), account: "widget-check")
    }
    static func acknowledge() {
        guard AppConfiguration.personalSpotify,
              let data = try? SharedKeychain().read("widget-check"),
              var check = try? JSONDecoder().decode(Check.self, from: data) else { return }
        check.acknowledgedAt = Date()
        if let encoded = try? JSONEncoder().encode(check) { try? SharedKeychain().write(encoded, account: "widget-check") }
    }
    static func status() -> String {
        guard let data = try? SharedKeychain().read("widget-check"),
              let check = try? JSONDecoder().decode(Check.self, from: data) else { return "Проверка ещё не запускалась" }
        guard let date = check.acknowledgedAt else { return "Ожидается обновление добавленного виджета" }
        return "Виджет прочитал общие данные: " + date.formatted(date: .omitted, time: .standard)
    }
}
