import XCTest
@testable import SpotifyCarWidget

final class SpotifyAPITests: XCTestCase {
    func testDecodePlaybackWithoutDeprecatedFields() async throws {
        let (api, _, _) = Fixtures.api([.init(body: Fixtures.playback)])
        let value = try await api.playback()
        XCTAssertEqual(value.title, "Night road")
        XCTAssertEqual(value.artist, "Fictional artist")
        XCTAssertEqual(value.durationMS, 180000)
        XCTAssertEqual(value.progressMS, 42000)
        XCTAssertEqual(value.artworkURL?.lastPathComponent, "medium")
        XCTAssertEqual(value.status, .ready)
        XCTAssertFalse(value.permits(.previous))
        XCTAssertTrue(value.permits(.toggle))
    }
    func test204MeansNoPlayback() async throws {
        let (api, _, _) = Fixtures.api([.init(status: 204)])
        let value = try await api.playback()
        XCTAssertEqual(value.status, .noPlayback)
        XCTAssertFalse(value.permits(.toggle))
    }
    func testFlatActionsRestrictionsAlsoDecode() throws {
        let payload = Fixtures.playback.replacingOccurrences(
            of: "\"actions\":{\"disallows\":{\"skipping_prev\":true,\"pausing\":false}}",
            with: "\"actions\":{\"skipping_prev\":true,\"pausing\":false}")
        let snapshot = try JSONDecoder().decode(PlayerResponse.self, from: Data(payload.utf8)).snapshot()
        XCTAssertFalse(snapshot.permits(.previous))
        XCTAssertTrue(snapshot.permits(.toggle))
    }
    func testNullItemAndEpisode() throws {
        let empty = try JSONDecoder().decode(PlayerResponse.self, from: Data("{\"item\":null}".utf8)).snapshot()
        XCTAssertEqual(empty.status, .noPlayback)
        let episode = try JSONDecoder().decode(PlayerResponse.self, from: Data("{\"item\":{\"type\":\"episode\",\"name\":\"Podcast\"}}".utf8)).snapshot()
        XCTAssertEqual(episode.status, .unavailable)
    }
    func testInactiveDevice() throws {
        let json = Fixtures.playback.replacingOccurrences(of: "\"is_active\":true", with: "\"is_active\":false")
        let value = try JSONDecoder().decode(PlayerResponse.self, from: Data(json.utf8)).snapshot()
        XCTAssertEqual(value.status, .noDevice)
        XCTAssertFalse(value.permits(.next))
    }
    func test401RefreshAndRetryOnce() async throws {
        let (api, mock, store) = Fixtures.api([
            .init(status: 401), .init(body: "{\"access_token\":\"renewed\",\"expires_in\":3600}"), .init(body: Fixtures.playback)
        ])
        _ = try await api.playback()
        let requests = await mock.requests
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests[2].value(forHTTPHeaderField: "Authorization"), "Bearer renewed")
        XCTAssertEqual(try store.read()?.refreshToken, "refresh")
    }
    func testRepeated401Stops() async throws {
        let (api, mock, _) = Fixtures.api([.init(status: 401), .init(body: "{\"access_token\":\"renewed\",\"expires_in\":3600}"), .init(status: 401)])
        do { _ = try await api.playback(); XCTFail("Expected unauthorized") }
        catch APIError.unauthorized { }
        let count = await mock.requests.count
        XCTAssertEqual(count, 3)
    }
    func testExpiredTokenRefreshesBeforeRequest() async throws {
        let store = MemoryTokens(OAuthTokens(accessToken: "old", refreshToken: "r", expiresAt: .distantPast))
        let (api, mock, _) = Fixtures.api([.init(body: "{\"access_token\":\"new\",\"refresh_token\":\"rotated\",\"expires_in\":3600}"), .init(status: 204)], store: store)
        _ = try await api.playback()
        let requests = await mock.requests
        XCTAssertEqual(requests[0].url?.host, "accounts.spotify.com")
        XCTAssertEqual(try store.read()?.refreshToken, "rotated")
    }
    func test403IsActionableAndNotRetried() async throws {
        let (api, mock, _) = Fixtures.api([.init(status: 403)])
        do { _ = try await api.playback(); XCTFail("Expected forbidden") }
        catch APIError.forbidden { }
        let count = await mock.requests.count
        XCTAssertEqual(count, 1)
    }
    func test404MeansNoActiveDevice() async throws {
        let (api, _, _) = Fixtures.api([.init(status: 404)])
        do { try await api.command(.next, isPlaying: true); XCTFail("Expected no device") }
        catch APIError.noDevice { }
    }
    func test429HonorsRetryAfterAndDoesNotSleep() async throws {
        let (api, mock, _) = Fixtures.api([.init(status: 429, headers: ["Retry-After": "120"])])
        do { _ = try await api.playback(); XCTFail("Expected rate limit") }
        catch APIError.rateLimited(let until) { XCTAssertGreaterThan(until.timeIntervalSinceNow, 118) }
        let count = await mock.requests.count
        XCTAssertEqual(count, 1)
    }
    func testRetryAfterHTTPDate() {
        let now = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(HTTPClient.retryDate("Thu, 01 Jan 1970 00:02:00 GMT", now: now), Date(timeIntervalSince1970: 120))
    }
    func testServerReadRetriesAreBounded() async throws {
        let (api, mock, _) = Fixtures.api([.init(status: 503), .init(status: 502), .init(status: 204)])
        _ = try await api.playback()
        let count = await mock.requests.count
        XCTAssertEqual(count, 3)
    }
    func testNextIsNeverRetriedOnServerError() async throws {
        let (api, mock, _) = Fixtures.api([.init(status: 503)])
        do { try await api.command(.next, isPlaying: true); XCTFail("Expected server failure") }
        catch APIError.server(503) { }
        let requests = await mock.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertEqual(requests[0].url?.path, "/v1/me/player/next")
    }
    func testWidgetReadDoesNotRetryServerFailure() async throws {
        let mock = MockTransport([.init(status: 503)])
        let http = HTTPClient(transport: mock, sleep: { _ in }, maxReadRetries: 0)
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player")!)
        request.httpMethod = "GET"
        do { _ = try await http.send(request, retryRead: true); XCTFail("Expected server failure") }
        catch APIError.server(503) { }
        let count = await mock.requests.count
        XCTAssertEqual(count, 1)
    }
    func testPauseAndResumeUsePUT() async throws {
        let (api, mock, _) = Fixtures.api([.init(status: 204), .init(status: 204)])
        try await api.command(.toggle, isPlaying: true)
        try await api.command(.toggle, isPlaying: false)
        let requests = await mock.requests
        XCTAssertEqual(requests.map(\.httpMethod), ["PUT", "PUT"])
        XCTAssertEqual(requests.map { $0.url!.lastPathComponent }, ["pause", "play"])
    }
}
