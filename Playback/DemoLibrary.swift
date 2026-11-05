import Foundation

enum DemoScenario: String, CaseIterable, Identifiable {
    case normal = "Обычный трек", longTitle = "Длинное название", missingArtwork = "Без обложки"
    case noPlayback = "Нет воспроизведения", error = "Ошибка сети"
    var id: String { rawValue }
}

enum DemoLibrary {
    static let tracks = [
        ("Midnight Drive", "North Avenue", "demo-midnight", 238_000),
        ("Golden Hour", "Mira & The Coast", "demo-golden", 196_000),
        ("After the Rain", "Slow Satellites", "demo-rain", 264_000)
    ]
    static func snapshot(index: Int, scenario: DemoScenario = .normal) -> PlaybackSnapshot {
        let track = tracks[((index % tracks.count) + tracks.count) % tracks.count]
        var result = PlaybackSnapshot(source: .demo, status: .ready)
        result.trackID = track.2; result.title = track.0; result.artist = track.1
        result.artworkKey = track.2; result.isPlaying = true
        result.durationMS = track.3; result.progressMS = 42_000
        result.observedAt = Date(); result.deviceActive = true
        switch scenario {
        case .normal: break
        case .longTitle:
            result.title = "Дорога сквозь огни большого города — бесконечная ночная версия"
            result.artist = "Очень длинное имя вымышленного исполнителя и его друзей"
        case .missingArtwork: result.artworkKey = nil
        case .noPlayback:
            result.status = .noPlayback; result.isPlaying = false; result.deviceActive = false
            result.trackID = nil; result.artworkKey = nil
            result.title = "Сейчас ничего не играет"; result.artist = "Запустите демонстрационный трек"
            result.durationMS = 0; result.progressMS = 0
        case .error:
            result.status = .failed; result.message = "Демонстрационная ошибка: сеть недоступна"
            result.observedAt = Date().addingTimeInterval(-900)
        }
        return result
    }
}
