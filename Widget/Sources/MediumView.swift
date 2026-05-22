import SwiftUI
import WidgetKit
import QuarantineShared

struct MediumView: View {
    let entry: QuarantineEntry

    private let quarantineAmber = Color(red: 0.97, green: 0.69, blue: 0.16)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("QUARANTINE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)

                Text("\(entry.state.needsReviewCount)")
                    .font(.system(size: 32, weight: .heavy,
                                  design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(entry.state.needsReviewCount > 0
                                     ? quarantineAmber : Color.primary)

                Text(entry.state.needsReviewCount == 0
                     ? "all clear"
                     : "to vet")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                if entry.state.totalCount > 0 {
                    Text("of \(entry.state.totalCount) downloads")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                // Two-button row: Defang (prominent — takes the
                // meaningful action on every needs-review item) +
                // Refresh (icon-only glyph button, secondary). Both
                // system styles so they stay legible across focused
                // / dimmed states on macOS Tahoe.
                HStack(spacing: 6) {
                    Button(intent: DefangNeedsReviewIntent()) {
                        Label("Defang", systemImage: "lock.shield")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(entry.state.needsReviewCount == 0)

                    Button(intent: RescanIntent()) {
                        Label("Rescan", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Rescan")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("RECENT")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                if entry.state.recent.isEmpty {
                    Text("no recent items")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(entry.state.recent.prefix(3),
                            id: \.name) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Circle()
                                .fill(badgeColor(row.badge))
                                .frame(width: 6, height: 6)
                            Text(row.name)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private func badgeColor(_ b: SharedQuarantine.Badge) -> Color {
        switch b {
        case .notarized:     return Color(red: 0.20, green: 0.75, blue: 0.42)
        case .signed:        return Color(red: 0.36, green: 0.72, blue: 1.00)
        case .unsigned:      return Color(red: 0.95, green: 0.35, blue: 0.35)
        case .notApplicable: return Color.gray
        case .unknown:       return Color(red: 0.97, green: 0.69, blue: 0.16)
        }
    }
}
