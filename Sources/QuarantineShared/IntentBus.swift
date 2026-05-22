import Foundation

/// Bridge between the widget's intents (RescanIntent,
/// DefangNeedsReviewIntent) and the running Quarantine host. The
/// host's AppDelegate calls `IntentBus.shared.register(...)` at
/// launch; each intent's perform() invokes the matching closure via
/// the bus.
///
/// No registered handler (e.g. intent firing too early, host hasn't
/// finished launching) → silent no-op rather than crash.
@MainActor
public final class IntentBus {
    public static let shared = IntentBus()
    private init() {}

    private var rescanHandler: (@MainActor () -> Void)?
    private var defangNeedsReviewHandler: (@MainActor () -> Void)?

    public func register(
        rescan: @escaping @MainActor () -> Void,
        defangNeedsReview: @escaping @MainActor () -> Void
    ) {
        self.rescanHandler = rescan
        self.defangNeedsReviewHandler = defangNeedsReview
    }

    public func rescan() { rescanHandler?() }
    public func defangNeedsReview() { defangNeedsReviewHandler?() }
}
