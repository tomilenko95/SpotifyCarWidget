import Foundation
import WidgetKit

actor SpotifyPlaybackService {
    static let shared: SpotifyPlaybackService = {
        #if WIDGET_EXTENSION
        return SpotifyPlaybackService(http: .widget)
        #else
        return SpotifyPlaybackService()
        #endif
    }()
    private let store: SharedStore?
    private let api: SpotifyAPI
    private let artwork: ArtworkCache?
    private var flight: Task<PlaybackSnapshot, Never>?
    private var flightID: UUID?
    init(store: SharedStore? = try? SharedStore.live(), tokenStore: any TokenStoring = KeychainTokenStore(),
         config: AppConfiguration = .current, http: HTTPClient = HTTPClient()) {
        self.store = store
        api = SpotifyAPI(tokens: TokenManager(store: tokenStore, config: config, http: http), http: http)
        artwork = store.map { ArtworkCache(root: $0.root) }
    }
    private func requiredStore() throws -> SharedStore {
        guard let store else { throw APIError.storage }; return store
    }
    func cached() -> PlaybackSnapshot {
        guard let store else {
            var result = PlaybackSnapshot(); result.status = .failed; result.message = APIError.storage.localizedDescription
            return result
        }
        return (try? store.read().snapshot) ?? .empty
    }
    func isDemo() -> Bool { (try? store?.read().demo) ?? true }
    func loggedIn() async -> Bool { (try? await api.tokens.loggedIn()) ?? false }
    func refresh() async -> PlaybackSnapshot {
        if let flight { return await flight.value }
        let id = UUID(); flightID = id
        let task = Task { await self.refreshOperation() }
        flight = task
        let value = await task.value
        if flightID == id { flight = nil; flightID = nil }
        return value
    }
    func cancelRefresh() { flight?.cancel(); flight = nil; flightID = nil }
    private func refreshOperation() async -> PlaybackSnapshot {
        do {
            let store = try requiredStore()
            return try await SharedGate.withLock(store: store) {
                var state = try store.read()
                if state.demo { try store.write(state); return state.snapshot }
                if let until = state.spotifyRetryAfter, until > Date() {
                    state.snapshot.retryAfter = until
                    return state.snapshot
                }
                // Coalesce independent app / widget reads that arrive together.
                if Date().timeIntervalSince(state.snapshot.observedAt) < 2 { return state.snapshot }
                do { state.snapshot = try await self.loadLive(); state.spotifyRetryAfter = nil; try store.write(state) }
                catch is CancellationError { return state.snapshot }
                catch { self.record(error, state: &state); try store.write(state) }
                return state.snapshot
            }
        } catch { return failure(error) }
    }
    private func loadLive() async throws -> PlaybackSnapshot {
        var snapshot = try await api.playback()
        if let url = snapshot.artworkURL { snapshot.artworkKey = try? await artwork?.cache(url) }
        try Task.checkCancellation()
        return snapshot
    }
    func perform(_ command: PlaybackCommand) async throws -> PlaybackSnapshot {
        let store = try requiredStore()
        return try await SharedGate.withLock(store: store) {
            var state = try store.read()
            if !state.demo, let until = state.spotifyRetryAfter, until > Date() { throw APIError.rateLimited(until) }
            if state.demo {
                guard state.snapshot.permits(command) else { return state.snapshot }
                switch command {
                case .toggle:
                    state.snapshot.progressMS = state.snapshot.progress(at: Date())
                    state.snapshot.observedAt = Date()
                    state.snapshot.isPlaying.toggle()
                case .next, .previous:
                    state.demoIndex = (state.demoIndex + (command == .next ? 1 : 2)) % DemoLibrary.tracks.count
                    state.snapshot = DemoLibrary.snapshot(index: state.demoIndex)
                }
            } else {
                do {
                    // Re-read playback before toggling: the widget snapshot may be several minutes old.
                    let current = try await self.api.playback()
                    guard current.permits(command) else {
                        state.snapshot = current; try store.write(state)
                        throw current.deviceActive ? APIError.actionUnavailable : APIError.noDevice
                    }
                    try await self.api.command(command, isPlaying: current.isPlaying)
                    // Spotify applies commands asynchronously. One bounded follow-up; no polling.
                    try await Task.sleep(nanoseconds: 400_000_000)
                    state.snapshot = try await self.loadLive()
                } catch {
                    self.record(error, state: &state); try store.write(state)
                    WidgetCenter.shared.reloadAllTimelines()
                    throw error
                }
            }
            try store.write(state)
            WidgetCenter.shared.reloadAllTimelines()
            return state.snapshot
        }
    }
    func setDemo(_ enabled: Bool, scenario: DemoScenario = .normal) async throws {
        cancelRefresh()
        let store = try requiredStore()
        try await SharedGate.withLock(store: store) {
            var state = try store.read()
            state.demo = AppConfiguration.personalDemo || enabled
            state.snapshot = state.demo ? DemoLibrary.snapshot(index: state.demoIndex, scenario: scenario) : .empty
            try store.write(state)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func accept(code: String, verifier: String) async throws {
        cancelRefresh()
        let store = try requiredStore()
        try await SharedGate.withLock(store: store) {
            try await self.api.tokens.exchange(code: code, verifier: verifier)
            var state = StoredPlayback(); state.demo = false; state.snapshot = .empty
            try store.write(state)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func logout() async throws {
        cancelRefresh()
        let store = try requiredStore()
        try await SharedGate.withLock(store: store) {
            try await self.api.tokens.logout()
            var state = StoredPlayback(); state.demo = false; state.snapshot = .empty
            if AppConfiguration.personalDemo { state = StoredPlayback() }
            try store.write(state)
            try await self.artwork?.clear()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func reloadWidgets() { WidgetCenter.shared.reloadAllTimelines() }
    private func record(_ error: Error, state: inout StoredPlayback) {
        state.snapshot.message = error.localizedDescription
        state.snapshot.status = .failed
        if case APIError.noDevice = error { state.snapshot.status = .noDevice; state.snapshot.deviceActive = false }
        if case APIError.unauthorized = error { state.snapshot.status = .signedOut }
        if case OAuthError.missingToken = error { state.snapshot.status = .signedOut }
        if case APIError.rateLimited(let until) = error {
            state.snapshot.retryAfter = until; state.spotifyRetryAfter = until
        }
    }
    private func failure(_ error: Error) -> PlaybackSnapshot {
        var snapshot = cached(); snapshot.status = .failed; snapshot.message = error.localizedDescription
        return snapshot
    }
}
