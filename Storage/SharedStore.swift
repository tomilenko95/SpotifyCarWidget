import Foundation
import Darwin

struct StoredPlayback: Codable, Sendable {
    var demo = true
    var snapshot: PlaybackSnapshot = DemoLibrary.snapshot(index: 0)
    var demoIndex = 0
    var spotifyRetryAfter: Date?
}

struct SharedStore: Sendable {
    let root: URL
    init(root: URL) { self.root = root }
    static func live() throws -> Self {
        if AppConfiguration.personalDemo {
            let local = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            return Self(root: local.appendingPathComponent("PersonalDemo", isDirectory: true))
        }
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfiguration.current.appGroup)
        else { throw APIError.storage }
        return Self(root: root)
    }
    func prepare() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    }
    var stateURL: URL { root.appendingPathComponent("playback.json") }
    func read() throws -> StoredPlayback {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return StoredPlayback() }
        return try JSONDecoder().decode(StoredPlayback.self, from: Data(contentsOf: stateURL))
    }
    func write(_ state: StoredPlayback) throws {
        try prepare()
        try JSONEncoder().encode(state).write(to: stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

enum SharedGate {
    // flock is released by the OS if an extension is terminated. Atomic JSON writes protect readers.
    static func withLock<T>(store: SharedStore, operation: () async throws -> T) async throws -> T {
        try store.prepare()
        let descriptor = open(store.root.appendingPathComponent("playback.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw APIError.storage }
        defer { flock(descriptor, LOCK_UN); close(descriptor) }
        let deadline = Date().addingTimeInterval(6)
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            try Task.checkCancellation()
            guard errno == EWOULDBLOCK, Date() < deadline else { throw APIError.busy }
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        try Task.checkCancellation()
        return try await operation()
    }
}
