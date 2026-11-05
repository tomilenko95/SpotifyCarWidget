import AppIntents
import WidgetKit

struct TogglePlaybackIntent: AppIntent {
    private var service: SpotifyPlaybackService
    init() { service = .shared }
    init(service: SpotifyPlaybackService) { self.service = service }
    static var title: LocalizedStringResource = "Воспроизведение / пауза"
    static var description = IntentDescription("Управляет Spotify на активном устройстве или локальным демо.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    func perform() async throws -> some IntentResult {
        _ = try await service.perform(.toggle)
        return .result()
    }
}
struct NextTrackIntent: AppIntent {
    private var service: SpotifyPlaybackService
    init() { service = .shared }
    init(service: SpotifyPlaybackService) { self.service = service }
    static var title: LocalizedStringResource = "Следующий трек"
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    func perform() async throws -> some IntentResult {
        _ = try await service.perform(.next)
        return .result()
    }
}
struct PreviousTrackIntent: AppIntent {
    private var service: SpotifyPlaybackService
    init() { service = .shared }
    init(service: SpotifyPlaybackService) { self.service = service }
    static var title: LocalizedStringResource = "Предыдущий трек"
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    func perform() async throws -> some IntentResult {
        _ = try await service.perform(.previous)
        return .result()
    }
}
