import WidgetKit
import SwiftUI

struct PlaybackEntry: TimelineEntry {
    let date: Date
    let snapshot: PlaybackSnapshot
}

struct PlaybackTimeline: TimelineProvider {
    func placeholder(in context: Context) -> PlaybackEntry { .init(date: Date(), snapshot: DemoLibrary.snapshot(index: 0)) }
    func getSnapshot(in context: Context, completion: @escaping (PlaybackEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { completion(.init(date: Date(), snapshot: await SpotifyPlaybackService.shared.cached())) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaybackEntry>) -> Void) {
        Task {
            let snapshot = await SpotifyPlaybackService.shared.refresh()
            WidgetConnectionCheck.acknowledge()
            completion(Self.timeline(snapshot: snapshot))
        }
    }
    static func timeline(snapshot: PlaybackSnapshot, now: Date = Date()) -> Timeline<PlaybackEntry> {
        // A request to WidgetKit, never a deadline guarantee. No per-second entries or polling.
        return Timeline(entries: [.init(date: now, snapshot: snapshot)], policy: .after(nextRefresh(snapshot: snapshot, now: now)))
    }
    static func nextRefresh(snapshot: PlaybackSnapshot, now: Date = Date()) -> Date {
        max(now.addingTimeInterval(900), snapshot.retryAfter ?? now)
    }
}
