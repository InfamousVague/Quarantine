import Foundation

/// Bridge between the widget's RescanIntent and the running
/// Quarantine host. The host's AppDelegate calls
/// `IntentBus.shared.register(...)` at launch; the intent's
/// perform() invokes the closure via the bus.
@MainActor
public final class IntentBus {
    public static let shared = IntentBus()
    private init() {}

    private var rescanHandler: (@MainActor () -> Void)?

    public func register(rescan: @escaping @MainActor () -> Void) {
        self.rescanHandler = rescan
    }

    public func rescan() { rescanHandler?() }
}
