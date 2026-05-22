import SwiftUI
import WidgetKit
import QuarantineShared

/// Small Quarantine layout: count of items to vet headline, total
/// inspected subtitle, Rescan pill at bottom.
struct SmallView: View {
    let entry: QuarantineEntry

    // Hardcoded yellow/amber matching the Quarantine app icon — accent
    // resolves to white on the widget surface so we go explicit.
    private let quarantineAmber = Color(red: 0.97, green: 0.69, blue: 0.16)

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Text("QUARANTINE")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.secondary)

            Text("\(entry.state.needsReviewCount)")
                .font(.system(size: 36, weight: .heavy,
                              design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(entry.state.needsReviewCount > 0
                                 ? quarantineAmber : Color.primary)

            Text(entry.state.needsReviewCount == 0
                 ? "all clear"
                 : (entry.state.needsReviewCount == 1
                    ? "to vet" : "to vet"))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            if entry.state.totalCount > 0 {
                Text("of \(entry.state.totalCount) downloads")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            // Two-button row: Defang (prominent, takes the meaningful
            // action on every needs-review item) + Refresh (icon-only
            // glyph button, the secondary "just re-check" action).
            // Both use system styles so they stay legible across the
            // widget's focused/dimmed states on macOS Tahoe.
            HStack(spacing: 6) {
                Button(intent: DefangNeedsReviewIntent()) {
                    Label("Defang", systemImage: "lock.shield")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(entry.state.needsReviewCount == 0)

                Button(intent: RescanIntent()) {
                    // Empty title → icon-only bordered glyph button.
                    Label("Rescan", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Rescan")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding(12)
    }
}
