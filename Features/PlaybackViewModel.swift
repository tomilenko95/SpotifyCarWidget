import SwiftUI

@MainActor
final class PlaybackViewModel: ObservableObject {
    @Published private(set) var snapshot = DemoLibrary.snapshot(index: 0)
    @Published private(set) var busy = false
    @Published private(set) var loggedIn = false
    @Published private(set) var demo = true
    @Published var error: String?
    let service: SpotifyPlaybackService
    private let auth = SpotifyAuthenticator()
    private var task: Task<Void, Never>?
    init(service: SpotifyPlaybackService = .shared) { self.service = service }
    func activate() { guard !busy else { return }; launch { await self.update() } }
    func suspend() { task?.cancel(); busy = false; auth.cancel(); Task { await service.cancelRefresh() } }
    func refresh() { guard !busy else { return }; launch { await self.update() } }
    func command(_ command: PlaybackCommand) {
        guard !busy else { return }
        launch {
            do { self.snapshot = try await self.service.perform(command) }
            catch { self.error = error.localizedDescription; self.snapshot = await self.service.cached() }
        }
    }
    func login() {
        launch {
            do { try await self.auth.login(service: self.service); await self.update() }
            catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
    func logout() {
        launch {
            do { try await self.service.logout(); await self.update() }
            catch { self.error = error.localizedDescription }
        }
    }
    func setDemo(_ value: Bool, scenario: DemoScenario = .normal) {
        launch {
            do { try await self.service.setDemo(value, scenario: scenario); await self.update() }
            catch { self.error = error.localizedDescription }
        }
    }
    private func update() async {
        let value = await service.refresh()
        guard !Task.isCancelled else { return }
        snapshot = value; demo = await service.isDemo(); loggedIn = await service.loggedIn()
        await service.reloadWidgets()
    }
    private func launch(_ operation: @escaping @MainActor () async -> Void) {
        task?.cancel()
        busy = true
        task = Task {
            await operation()
            if !Task.isCancelled { busy = false }
        }
    }
}
