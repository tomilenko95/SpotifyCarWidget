import Foundation

actor TokenManager {
    private let store: any TokenStoring
    private let config: AppConfiguration
    private let http: HTTPClient
    init(store: any TokenStoring, config: AppConfiguration, http: HTTPClient) {
        self.store = store; self.config = config; self.http = http
    }
    // Called under SharedGate by PlaybackService (also across app / extension processes).
    func accessToken(force: Bool = false, rejected: String? = nil) async throws -> String {
        guard let tokens = try store.read() else { throw OAuthError.missingToken }
        if let rejected, tokens.accessToken != rejected { return tokens.accessToken }
        if !force && tokens.expiresAt.timeIntervalSinceNow > 60 { return tokens.accessToken }
        return try await request(["grant_type": "refresh_token", "refresh_token": tokens.refreshToken,
                                  "client_id": config.clientID], previousRefresh: tokens.refreshToken).accessToken
    }
    func exchange(code: String, verifier: String) async throws {
        _ = try await request(["grant_type": "authorization_code", "code": code, "redirect_uri": config.redirectURI,
                               "client_id": config.clientID, "code_verifier": verifier], previousRefresh: nil)
    }
    private func request(_ fields: [String: String], previousRefresh: String?) async throws -> OAuthTokens {
        struct Response: Decodable { var access_token: String; var refresh_token: String?; var expires_in: Int }
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = HTTPClient.form(fields)
        let data: Data
        do { data = try await http.send(request).0 }
        catch APIError.server(400) {
            // An invalid/expired refresh grant cannot be recovered by retrying it.
            if previousRefresh != nil { try store.clear() }
            throw OAuthError.missingToken
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let refresh = response.refresh_token ?? previousRefresh, !refresh.isEmpty else { throw OAuthError.missingToken }
        let tokens = OAuthTokens(accessToken: response.access_token, refreshToken: refresh,
                                 expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in)))
        try store.write(tokens)
        return tokens
    }
    func loggedIn() throws -> Bool { try store.read() != nil }
    func logout() throws { try store.clear() }
}

struct SpotifyAPI: Sendable {
    let tokens: TokenManager
    var http: HTTPClient
    func request(path: String = "", method: String = "GET") async throws -> (Data, HTTPURLResponse) {
        let token = try await tokens.accessToken()
        func make(_ bearer: String) -> URLRequest {
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player\(path)")!)
            request.httpMethod = method
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
            return request
        }
        do { return try await http.send(make(token), retryRead: method == "GET") }
        catch APIError.unauthorized {
            let renewed = try await tokens.accessToken(force: true, rejected: token)
            return try await http.send(make(renewed), retryRead: method == "GET")
        }
    }
    func playback() async throws -> PlaybackSnapshot {
        let (data, response) = try await request()
        if response.statusCode == 204 {
            var snapshot = PlaybackSnapshot(); snapshot.status = .noPlayback; snapshot.observedAt = Date()
            return snapshot
        }
        return try JSONDecoder().decode(PlayerResponse.self, from: data).snapshot()
    }
    func command(_ command: PlaybackCommand, isPlaying: Bool) async throws {
        switch command {
        case .toggle: _ = try await request(path: isPlaying ? "/pause" : "/play", method: "PUT")
        case .next: _ = try await request(path: "/next", method: "POST")
        case .previous: _ = try await request(path: "/previous", method: "POST")
        }
    }
}
