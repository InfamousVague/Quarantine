import Foundation

/// Compact widget-facing snapshot of ~/Downloads' trust posture.
/// Host writes after each rescan; widget timeline reads.
public struct SharedQuarantine: Codable, Sendable, Equatable {

    /// Coarse trust badge for widget display. Mirrors the pane's
    /// TrustLevel enum without bringing the whole signature module
    /// into the widget extension.
    public enum Badge: String, Codable, Sendable {
        case notarized, signed, unsigned, notApplicable, unknown
    }

    public struct Row: Codable, Sendable, Equatable, Hashable {
        public let name: String
        public let badge: Badge
        public init(name: String, badge: Badge) {
            self.name = name
            self.badge = badge
        }
    }

    /// Total inspected files in ~/Downloads.
    public var totalCount: Int
    /// Subset that warrants user review (unsigned / unknown trust).
    public var needsReviewCount: Int
    /// Top 3 most-recent items for the medium tile.
    public var recent: [Row]
    public var sampledAt: Date

    public init(
        totalCount: Int = 0,
        needsReviewCount: Int = 0,
        recent: [Row] = [],
        sampledAt: Date = .distantPast
    ) {
        self.totalCount = totalCount
        self.needsReviewCount = needsReviewCount
        self.recent = recent
        self.sampledAt = sampledAt
    }
}
