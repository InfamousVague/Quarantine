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

            Button(intent: RescanIntent()) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Rescan")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(quarantineAmber, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding(12)
    }
}
