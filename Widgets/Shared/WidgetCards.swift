import SwiftUI
import WidgetKit
import UIKit

struct AlbumArtwork: View {
    let snapshot: PlaybackSnapshot
    private var image: UIImage? {
        if snapshot.source == .demo, let key = snapshot.artworkKey { return UIImage(named: key) }
        return ArtworkCache.image(key: snapshot.artworkKey, root: (try? SharedStore.live())?.root)
    }
    var body: some View {
        ZStack {
            Color.gray.opacity(0.18)
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityLabel(snapshot.artworkKey == nil ? "Нет обложки" : "Обложка альбома")
    }
}

private struct WidgetInk: ViewModifier {
    @Environment(\.showsWidgetContainerBackground) private var hasBackground
    func body(content: Content) -> some View { content.foregroundStyle(hasBackground ? Color.white : Color.primary) }
}

struct SpotifyBadge: View {
    let demo: Bool
    var body: some View {
        Group {
            if demo {
                Text("ДЕМО").font(.system(size: 10, weight: .semibold))
            } else {
                Image("spotify-icon").renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 21, height: 21).padding(.horizontal, 11)
            }
        }.accessibilityLabel(demo ? "Демонстрация, вымышленные треки" : "Источник: Spotify")
    }
}

struct SnapshotCaption: View {
    let snapshot: PlaybackSnapshot
    var body: some View {
        HStack(spacing: 3) {
            SpotifyBadge(demo: snapshot.source == .demo)
            Spacer(minLength: 2)
            if snapshot.status != .ready {
                Image(systemName: "exclamationmark.circle")
                    .accessibilityLabel(snapshot.status.title)
            } else if snapshot.isStale && snapshot.source != .demo {
                Image(systemName: "clock.badge.exclamationmark").accessibilityLabel("Данные устарели")
            }
        }.font(.system(size: 10)).foregroundStyle(.secondary)
    }
}

struct WidgetPlayButton: View {
    let snapshot: PlaybackSnapshot
    var body: some View {
        Button(intent: TogglePlaybackIntent()) {
            Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!snapshot.permits(.toggle))
        .accessibilityLabel(snapshot.isPlaying ? "Пауза" : "Воспроизвести")
    }
}

struct CompactCard: View {
    let snapshot: PlaybackSnapshot
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    AlbumArtwork(snapshot: snapshot)
                        .frame(width: min(78, geometry.size.height * 0.43), height: min(78, geometry.size.height * 0.43))
                    WidgetPlayButton(snapshot: snapshot)
                }
                Text(snapshot.status == .ready || snapshot.trackID != nil ? snapshot.title : snapshot.status.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(2).minimumScaleFactor(0.8)
                Text(snapshot.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
                SnapshotCaption(snapshot: snapshot)
            }
        }.modifier(WidgetInk())
    }
}

struct ControlsCard: View {
    let snapshot: PlaybackSnapshot
    var wide = false
    var body: some View {
        HStack(spacing: 12) {
            if wide { AlbumArtwork(snapshot: snapshot).frame(maxWidth: 115) }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    if !wide { AlbumArtwork(snapshot: snapshot).frame(width: 36, height: 36) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.trackID == nil ? snapshot.status.title : snapshot.title)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold)).lineLimit(2)
                        Text(snapshot.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                ProgressView(value: Double(snapshot.progress(at: .now)), total: Double(max(1, snapshot.durationMS)))
                    .tint(.green).accessibilityLabel("Последний известный прогресс")
                if wide {
                    HStack {
                        Text(Self.time(snapshot.progress(at: .now)))
                        Spacer()
                        Text(Self.time(snapshot.durationMS))
                    }.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                HStack(spacing: 0) {
                    Button(intent: PreviousTrackIntent()) {
                        Image(systemName: "backward.end.fill").frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }.disabled(!snapshot.permits(.previous)).accessibilityLabel("Предыдущий трек")
                    WidgetPlayButton(snapshot: snapshot)
                    Button(intent: NextTrackIntent()) {
                        Image(systemName: "forward.end.fill").frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }.disabled(!snapshot.permits(.next)).accessibilityLabel("Следующий трек")
                }.buttonStyle(.plain).font(.system(size: 18, weight: .semibold))
                SnapshotCaption(snapshot: snapshot)
            }
        }.modifier(WidgetInk())
    }
    static func time(_ milliseconds: Int) -> String {
        let seconds = max(0, milliseconds / 1000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct DecorativeWave: View {
    private let heights: [CGFloat] = [5, 10, 17, 8, 20, 12, 7, 16, 22, 10, 5, 13, 18, 8, 12, 5]
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                Capsule().frame(width: 3, height: height)
            }
        }.accessibilityHidden(true)
    }
}

struct CoverFocusCard: View {
    let snapshot: PlaybackSnapshot
    var body: some View {
        GeometryReader { geometry in
            if snapshot.source == .demo {
                ZStack(alignment: .bottomLeading) {
                    AlbumArtwork(snapshot: snapshot).frame(width: geometry.size.width, height: geometry.size.width)
                        .frame(height: geometry.size.height).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 3) {
                        DecorativeWave().foregroundStyle(.white.opacity(0.7)).scaleEffect(y: 0.7, anchor: .bottom)
                        Text(snapshot.title).font(.system(.headline, design: .rounded, weight: .semibold)).lineLimit(2)
                        Text(snapshot.artist).font(.caption).lineLimit(1).foregroundStyle(.white.opacity(0.8))
                        SnapshotCaption(snapshot: snapshot)
                    }.padding(8).foregroundStyle(.white)
                }.clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Spotify design rules: preserve album art, with metadata and decoration outside it.
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        AlbumArtwork(snapshot: snapshot)
                            .frame(width: min(geometry.size.width * 0.65, geometry.size.height * 0.43))
                        DecorativeWave().scaleEffect(x: 0.35, anchor: .leading).frame(width: 20)
                    }
                    Text(snapshot.trackID == nil ? snapshot.status.title : snapshot.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                    Text(snapshot.artist).font(.caption2).lineLimit(1).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    SnapshotCaption(snapshot: snapshot)
                }.modifier(WidgetInk())
            }
        }
    }
}

#Preview("Тёмная • длинное название") {
    ControlsCard(snapshot: DemoLibrary.snapshot(index: 0, scenario: .longTitle))
        .padding().frame(width: 170, height: 170).background(.black).preferredColorScheme(.dark)
}
#Preview("Светлая • без обложки") {
    CompactCard(snapshot: DemoLibrary.snapshot(index: 0, scenario: .missingArtwork))
        .padding().frame(width: 170, height: 170).background(.black).preferredColorScheme(.light)
}
