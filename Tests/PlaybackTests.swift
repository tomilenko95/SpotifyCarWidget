import XCTest
import WidgetKit
import AppIntents
@testable import SpotifyCarWidget

final class PlaybackTests: XCTestCase {
    func testSharedLeaseHasBoundedExpiryAndPreservesOwner() throws {
        let now = Date()
        let lease = SharedLeaseRecord(owner: "owner-one", expiresAt: now.addingTimeInterval(120))
        XCTAssertFalse(lease.isExpired(at: now))
        XCTAssertTrue(lease.isExpired(at: now.addingTimeInterval(120)))
        XCTAssertEqual(try JSONDecoder().decode(SharedLeaseRecord.self, from: JSONEncoder().encode(lease)), lease)
    }
    func testRealProgressDoesNotInventRealtimeUpdates() {
        var value = DemoLibrary.snapshot(index: 0); value.source = .spotify
        XCTAssertEqual(value.progress(at: value.observedAt.addingTimeInterval(600)), value.progressMS)
    }
    func testDemoProgressClampedToDuration() {
        let value = DemoLibrary.snapshot(index: 0)
        XCTAssertEqual(value.progress(at: value.observedAt.addingTimeInterval(600)), value.durationMS)
    }
    func testSnapshotRoundTrip() throws {
        let value = DemoLibrary.snapshot(index: 1)
        XCTAssertEqual(try JSONDecoder().decode(PlaybackSnapshot.self, from: JSONEncoder().encode(value)), value)
    }
    func testDemoControlsNeverReachNetwork() async throws {
        let store = try Fixtures.temporaryStore(); defer { try? FileManager.default.removeItem(at: store.root) }
        let mock = MockTransport([])
        let service = SpotifyPlaybackService(store: store, tokenStore: MemoryTokens(), config: Fixtures.config, http: HTTPClient(transport: mock))
        try await service.setDemo(true)
        let before = await service.cached()
        let paused = try await service.perform(.toggle)
        XCTAssertFalse(paused.isPlaying)
        let next = try await service.perform(.next)
        XCTAssertNotEqual(before.trackID, next.trackID)
        let count = await mock.requests.count
        XCTAssertEqual(count, 0)
    }
    func testAllIntentsPerformAgainstInjectedDemo() async throws {
        let store = try Fixtures.temporaryStore(); defer { try? FileManager.default.removeItem(at: store.root) }
        let service = SpotifyPlaybackService(store: store, tokenStore: MemoryTokens())
        try await service.setDemo(true)
        let before = await service.cached()
        _ = try await TogglePlaybackIntent(service: service).perform()
        let paused = await service.cached()
        XCTAssertFalse(paused.isPlaying)
        _ = try await NextTrackIntent(service: service).perform()
        _ = try await PreviousTrackIntent(service: service).perform()
        let after = await service.cached()
        XCTAssertEqual(before.trackID, after.trackID)
        XCTAssertFalse(TogglePlaybackIntent.openAppWhenRun)
    }
    func testCrossInstanceStorageIsShared() async throws {
        let store = try Fixtures.temporaryStore(); defer { try? FileManager.default.removeItem(at: store.root) }
        let first = SpotifyPlaybackService(store: store, tokenStore: MemoryTokens())
        let second = SpotifyPlaybackService(store: store, tokenStore: MemoryTokens())
        try await first.setDemo(true, scenario: .longTitle)
        let one = await first.cached(); let two = await second.cached()
        XCTAssertEqual(one, two)
    }
    func testRateLimitPersistsAndBlocksOtherInstance() async throws {
        let store = try Fixtures.temporaryStore(); defer { try? FileManager.default.removeItem(at: store.root) }
        var state = StoredPlayback(); state.demo = false; state.snapshot = .empty
        try store.write(state)
        let mock = MockTransport([.init(status: 429, headers: ["Retry-After": "120"])])
        let service = SpotifyPlaybackService(store: store, tokenStore: MemoryTokens(Fixtures.validTokens), config: Fixtures.config, http: HTTPClient(transport: mock))
        let value = await service.refresh()
        XCTAssertNotNil(value.retryAfter)
        _ = await service.refresh()
        let count = await mock.requests.count
        XCTAssertEqual(count, 1)
        XCTAssertNotNil(try store.read().snapshot.retryAfter)
    }
    func testConcurrentRefreshDeduplicates() async throws {
        let store = try Fixtures.temporaryStore(); defer { try? FileManager.default.removeItem(at: store.root) }
        var state = StoredPlayback(); state.demo = false; state.snapshot = .empty; try store.write(state)
        let mock = MockTransport([.init(status: 204)])
        let service = SpotifyPlaybackService(store: store, tokenStore: MemoryTokens(Fixtures.validTokens), config: Fixtures.config, http: HTTPClient(transport: mock))
        async let first = service.refresh()
        async let second = service.refresh()
        _ = await (first, second)
        let count = await mock.requests.count
        XCTAssertEqual(count, 1)
    }
    func testCommandUsesFreshPlayStateInsteadOfStaleWidget() async throws {
        let store = try Fixtures.temporaryStore(); defer { try? FileManager.default.removeItem(at: store.root) }
        var state = StoredPlayback(); state.demo = false
        state.snapshot = DemoLibrary.snapshot(index: 0); state.snapshot.source = .spotify
        state.snapshot.isPlaying = true
        try store.write(state)
        let paused = """
        {"device":{"is_active":true},"is_playing":false,"item":{"id":"one","name":"Track","type":"track","duration_ms":1000}}
        """
        let mock = MockTransport([.init(body: paused), .init(status: 204), .init(body: paused)])
        let service = SpotifyPlaybackService(store: store, tokenStore: MemoryTokens(Fixtures.validTokens),
            config: Fixtures.config, http: HTTPClient(transport: mock, sleep: { _ in }))
        _ = try await service.perform(.toggle)
        let requests = await mock.requests
        XCTAssertEqual(requests[1].url?.lastPathComponent, "play")
        XCTAssertEqual(requests.count, 3)
    }
    func testSwitchingDemoDoesNotBypassSpotifyCooldown() async throws {
        let store = try Fixtures.temporaryStore(); defer { try? FileManager.default.removeItem(at: store.root) }
        var state = StoredPlayback(); state.demo = false; state.snapshot = .empty
        state.spotifyRetryAfter = Date().addingTimeInterval(120)
        try store.write(state)
        let mock = MockTransport([])
        let service = SpotifyPlaybackService(store: store, tokenStore: MemoryTokens(Fixtures.validTokens),
            config: Fixtures.config, http: HTTPClient(transport: mock))
        try await service.setDemo(true)
        try await service.setDemo(false)
        let value = await service.refresh()
        XCTAssertNotNil(value.retryAfter)
        let count = await mock.requests.count
        XCTAssertEqual(count, 0)
    }
    func testLogoutClearsTokensAndCachedSpotifyData() async throws {
        let store = try Fixtures.temporaryStore(); defer { try? FileManager.default.removeItem(at: store.root) }
        let tokens = MemoryTokens(Fixtures.validTokens)
        let service = SpotifyPlaybackService(store: store, tokenStore: tokens)
        try await service.logout()
        XCTAssertNil(try tokens.read())
        XCTAssertNil(try store.read().snapshot.trackID)
    }
    func testTimelineRespectsLongRetryAfter() {
        let now = Date()
        var snapshot = DemoLibrary.snapshot(index: 0)
        snapshot.retryAfter = now.addingTimeInterval(3600)
        let timeline = PlaybackTimeline.timeline(snapshot: snapshot, now: now)
        XCTAssertEqual(timeline.entries.count, 1)
        XCTAssertGreaterThanOrEqual(PlaybackTimeline.nextRefresh(snapshot: snapshot, now: now), snapshot.retryAfter!)
    }
    func testArtworkKeyCannotEscapeCache() {
        XCTAssertNil(ArtworkCache.image(key: "../../secret", root: FileManager.default.temporaryDirectory))
    }
}
