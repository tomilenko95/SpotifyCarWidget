import SwiftUI
import WidgetKit

struct CompactWidget: Widget {
    let kind = "SpotifyCompact"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaybackTimeline()) { entry in
            CompactCard(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color(red: 0.055, green: 0.065, blue: 0.08) }
        }
        .configurationDisplayName("Compact")
        .description("Крупная обложка и одна кнопка воспроизведения.")
        .supportedFamilies([.systemSmall])
        .containerBackgroundRemovable(true)
    }
}

#Preview(as: .systemSmall) { CompactWidget() } timeline: {
    PlaybackEntry(date: .now, snapshot: DemoLibrary.snapshot(index: 0))
    PlaybackEntry(date: .now, snapshot: DemoLibrary.snapshot(index: 0, scenario: .longTitle))
    PlaybackEntry(date: .now, snapshot: DemoLibrary.snapshot(index: 0, scenario: .missingArtwork))
}
