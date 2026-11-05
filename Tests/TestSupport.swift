import XCTest
@testable import SpotifyCarWidget

final class MemoryTokens: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: OAuthTokens?
    init(_ value: OAuthTokens? = nil) { self.value = value }
    func read() throws -> OAuthTokens? { lock.lock(); defer { lock.unlock() }; return value }
    func write(_ tokens: OAuthTokens) throws { lock.lock(); defer { lock.unlock() }; value = tokens }
    func clear() throws { lock.lock(); defer { lock.unlock() }; value = nil }
}

actor MockTransport: HTTPTransport {
    struct Reply: Sendable {
        var status = 200
        var body = ""
        var headers: [String: String] = [:]
    }
    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []
    init(_ replies: [Reply]) { self.replies = replies }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.badServerResponse) }
        let reply = replies.removeFirst()
        return (Data(reply.body.utf8), HTTPURLResponse(url: request.url!, statusCode: reply.status,
            httpVersion: "HTTP/1.1", headerFields: reply.headers)!)
    }
}

enum Fixtures {
    static let config = AppConfiguration(clientID: String(repeating: "a", count: 32),
        redirectURI: "https://login.test.org/spotify/callback", appGroup: "test", keychainGroup: nil)
    static let playback = """
    {"device":{"is_active":true,"is_restricted":false},"timestamp":1730000000000,
    "progress_ms":42000,"is_playing":true,"currently_playing_type":"track",
    "item":{"id":"track1","name":"Night road","type":"track","duration_ms":180000,
    "artists":[{"name":"Fictional artist"}],"album":{"images":[
    {"url":"https://i.scdn.co/image/large","width":640},
    {"url":"https://i.scdn.co/image/medium","width":300}]},
    "external_urls":{"spotify":"https://open.spotify.com/track/track1"}},
    "actions":{"disallows":{"skipping_prev":true,"pausing":false}}}
    """
    static var validTokens: OAuthTokens {
        OAuthTokens(accessToken: "valid", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(3600))
    }
    static func api(_ replies: [MockTransport.Reply], store: MemoryTokens? = nil) -> (SpotifyAPI, MockTransport, MemoryTokens) {
        let mock = MockTransport(replies)
        let store = store ?? MemoryTokens(validTokens)
        let http = HTTPClient(transport: mock, sleep: { _ in })
        return (SpotifyAPI(tokens: TokenManager(store: store, config: config, http: http), http: http), mock, store)
    }
    static func temporaryStore() throws -> SharedStore {
        let store = SharedStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try store.prepare()
        return store
    }
}
