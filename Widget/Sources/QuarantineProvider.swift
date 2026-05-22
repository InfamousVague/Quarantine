import WidgetKit
import QuarantineShared

struct QuarantineEntry: TimelineEntry {
    let date: Date
    let state: SharedQuarantine
    var isStale: Bool {
        Date().timeIntervalSince(state.sampledAt) > 120
    }
}

struct QuarantineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuarantineEntry {
        QuarantineEntry(date: .now, state: SharedQuarantine())
    }
    func getSnapshot(in context: Context,
                     completion: @escaping (QuarantineEntry) -> Void)
    {
        completion(QuarantineEntry(
            date: .now, state: SharedQuarantineStore.read()))
    }
    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<QuarantineEntry>) -> Void)
    {
        let entry = QuarantineEntry(
            date: .now, state: SharedQuarantineStore.read())
        // 5-minute safety net; host writes invalidate sooner whenever
        // a rescan lands.
        let next = Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry],
                            policy: .after(next)))
    }
}
