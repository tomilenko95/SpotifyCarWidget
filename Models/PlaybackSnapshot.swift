import Foundation

enum PlaybackSource: String, Codable, Sendable { case spotify, demo }
enum PlaybackStatus: String, Codable, Sendable {
    case ready, signedOut, noDevice, noPlayback, unavailable, failed
    var title: String {
        switch self {
        case .ready: return "Подключено"
        case .signedOut: return "Войдите в Spotify на iPhone"
        case .noDevice: return "Запустите Spotify на устройстве"
        case .noPlayback: return "Сейчас ничего не играет"
        case .unavailable: return "Этот контент недоступен"
        case .failed: return "Не удалось обновить"
        }
    }
}

struct PlaybackSnapshot: Codable, Equatable, Sendable {
    var source: PlaybackSource = .spotify
    var status: PlaybackStatus = .signedOut
    var trackID: String?
    var title = "Ваша музыка в пути"
    var artist = "Spotify CarWidget"
    var artworkURL: URL?
    var artworkKey: String?
    var spotifyURL: URL?
    var isPlaying = false
    var durationMS = 0
    var progressMS = 0
    var observedAt: Date = .distantPast
    var serverTimestamp: Date?
    var deviceActive = false
    var disallowed: Set<String> = []
    var message: String?
    var retryAfter: Date?

    static let empty = PlaybackSnapshot()
    var isStale: Bool { Date().timeIntervalSince(observedAt) > 300 }
    // Real playback deliberately uses the last confirmed value. No speculative track rollover.
    func progress(at date: Date) -> Int {
        let extra = source == .demo && isPlaying ? max(0, date.timeIntervalSince(observedAt)) * 1000 : 0
        return min(max(0, durationMS), max(0, progressMS + Int(extra)))
    }
    func permits(_ command: PlaybackCommand) -> Bool {
        guard status == .ready, deviceActive else { return false }
        let key: String
        switch command {
        case .toggle: key = isPlaying ? "pausing" : "resuming"
        case .next: key = "skipping_next"
        case .previous: key = "skipping_prev"
        }
        return !disallowed.contains(key)
    }
}

enum PlaybackCommand: String, Sendable { case toggle, next, previous }

struct PlayerResponse: Decodable, Sendable {
    struct Device: Decodable, Sendable { var is_active: Bool?; var is_restricted: Bool? }
    struct Artist: Decodable, Sendable { var name: String }
    struct Artwork: Decodable, Sendable { var url: URL; var width: Int? }
    struct Album: Decodable, Sendable { var images: [Artwork]? }
    struct Item: Decodable, Sendable {
        var id: String?; var name: String?; var type: String?; var duration_ms: Int?
        var artists: [Artist]?; var album: Album?; var external_urls: [String: URL]?
    }
    struct Actions: Decodable, Sendable {
        var disallows: [String: Bool]?
        private enum Keys: String, CodingKey { case disallows, pausing, resuming, skipping_next, skipping_prev }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: Keys.self)
            if let nested = try values.decodeIfPresent([String: Bool].self, forKey: .disallows) {
                disallows = nested
            } else {
                // Accept the published flat shape as well as nested disallows payloads.
                var flags: [String: Bool] = [:]
                for key in [Keys.pausing, .resuming, .skipping_next, .skipping_prev] {
                    flags[key.rawValue] = try values.decodeIfPresent(Bool.self, forKey: key)
                }
                disallows = flags
            }
        }
    }
    var device: Device?
    var timestamp: Double?
    var progress_ms: Int?
    var is_playing: Bool?
    var item: Item?
    var currently_playing_type: String?
    var actions: Actions?

    func snapshot(now: Date = Date()) -> PlaybackSnapshot {
        var result = PlaybackSnapshot()
        result.observedAt = now
        result.serverTimestamp = timestamp.map { Date(timeIntervalSince1970: $0 / 1000) }
        result.deviceActive = device?.is_active == true && device?.is_restricted != true
        guard let item else { result.status = .noPlayback; return result }
        guard item.type == "track" else { result.status = .unavailable; return result }
        result.status = result.deviceActive ? .ready : .noDevice
        result.trackID = item.id
        result.title = item.name ?? "Неизвестный трек"
        result.artist = item.artists?.map(\.name).joined(separator: ", ") ?? "Неизвестный исполнитель"
        result.artworkURL = item.album?.images?.min(by: {
            abs(($0.width ?? 300) - 300) < abs(($1.width ?? 300) - 300)
        })?.url
        result.spotifyURL = item.external_urls?["spotify"]
        result.isPlaying = is_playing ?? false
        result.durationMS = max(0, item.duration_ms ?? 0)
        result.progressMS = min(result.durationMS, max(0, progress_ms ?? 0))
        result.disallowed = Set((actions?.disallows ?? [:]).filter(\.value).map(\.key))
        return result
    }
}
