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

            // Same `.bordered` styling for both — borderedProminent
            // was washing out in the widget render pass (system
            // desaturates the accent fill against the dimmed
            // background) which made the Defang capsule unreadable.
            // Matching the Refresh glyph button keeps both legible
            // across focused / dimmed states.
            HStack(spacing: 6) {
                Button(intent: DefangNeedsReviewIntent()) {
                    Label("Defang", systemImage: "lock.shield")
                }
                .buttonStyle(.bordered)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding(12)
    }
}
