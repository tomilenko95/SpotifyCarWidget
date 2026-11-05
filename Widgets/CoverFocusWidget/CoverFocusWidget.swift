import SwiftUI
import WidgetKit

struct CoverFocusWidget: Widget {
    let kind = "SpotifyCoverFocus"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaybackTimeline()) { entry in
            CoverFocusCard(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.black }
        }
        .configurationDisplayName("Cover Focus")
        .description("Обложка, название и декоративная статическая волна.")
        .supportedFamilies([.systemSmall])
        .containerBackgroundRemovable(true)
    }
}
#Preview(as: .systemSmall) { CoverFocusWidget() } timeline: {
    PlaybackEntry(date: .now, snapshot: DemoLibrary.snapshot(index: 2))
    PlaybackEntry(date: .now, snapshot: DemoLibrary.snapshot(index: 0, scenario: .noPlayback))
}
