import SwiftUI
import WidgetKit

struct ControlsWidget: Widget {
    let kind = "SpotifyControls"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaybackTimeline()) { entry in
            ControlsEntryView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color(red: 0.055, green: 0.065, blue: 0.08) }
        }
        .configurationDisplayName("Controls")
        .description("Предыдущий, пауза и следующий. Прогресс на момент обновления.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(true)
    }
}
struct ControlsEntryView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: PlaybackSnapshot
    var body: some View { ControlsCard(snapshot: snapshot, wide: family == .systemMedium) }
}
#Preview(as: .systemSmall) { ControlsWidget() } timeline: {
    PlaybackEntry(date: .now, snapshot: DemoLibrary.snapshot(index: 1))
    PlaybackEntry(date: .now, snapshot: DemoLibrary.snapshot(index: 0, scenario: .error))
}
#Preview(as: .systemMedium) { ControlsWidget() } timeline: {
    PlaybackEntry(date: .now, snapshot: DemoLibrary.snapshot(index: 1))
}
