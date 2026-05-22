import Foundation

/// Shared App Group id used by both the Quarantine host AND the
/// widget extension. Must match `QuarantineWidgets.entitlements` and
/// the host `Quarantine.entitlements` — drift = silent failure.
public enum AppGroup {
    public static let id =
        "F6ZAL7ANAD.group.com.mattssoftware.quarantine"

    public static var containerURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: id)
    }
}
