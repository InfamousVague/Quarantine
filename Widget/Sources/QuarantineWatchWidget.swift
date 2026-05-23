import WidgetKit
import SwiftUI
import QuarantineShared

struct QuarantineWatchWidget: Widget {
    let kind: String = "QuarantineWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuarantineProvider()) {
            entry in
            QuarantineWidgetView(entry: entry)
                // Forces `.accented` in the SwiftUI subtree so any
                // adaptive code (button styles, image rendering)
                // reads the dimmed-glass mode regardless of the
                // widget's actual focus state. Visual consistency
                // matches the rest of the widget family.
                .environment(\.widgetRenderingMode, .accented)
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
        Group {
            switch family {
            case .systemSmall:  SmallView(entry: entry)
            case .systemMedium: MediumView(entry: entry)
            default:            SmallView(entry: entry)
            }
        }
        // Desktop-widget tap → MattsSoftware launcher pops its
        // popover already switched to the Quarantine pane. Without
        // this URL hook tapping launches the standalone bundle
        // id, SuiteGuard exits in merged mode, nothing visible.
        .widgetURL(URL(string: "mattssoftware://quarantine"))
    }
}
