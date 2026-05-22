import WidgetKit
import SwiftUI
import QuarantineShared

struct QuarantineWatchWidget: Widget {
    let kind: String = "QuarantineWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuarantineProvider()) {
            entry in
            QuarantineWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Downloads Watch")
        .description("How many recent downloads need vetting, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct QuarantineWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuarantineEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        default:            SmallView(entry: entry)
        }
    }
}
