import AppIntents

/// Widget button: rescan ~/Downloads. openAppWhenRun = true hands
/// execution to the host process where the privileged scanner runs.
public struct RescanIntent: AppIntent {
    public static var title: LocalizedStringResource =
        "Rescan downloads"
    public static var description = IntentDescription(
        "Re-inspect ~/Downloads and refresh trust badges.")
    public static var openAppWhenRun: Bool = true
    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        IntentBus.shared.rescan()
        return .result()
    }
}

/// Widget button: defang every non-defanged unsigned/unknown item.
/// The widget can't pick a specific file, so it operates on exactly
/// the set its `needsReviewCount` headline refers to. Each item gets
/// renamed `foo.dmg → foo.dmg.quarantine`, so a double-click can no
/// longer launch/mount it. Reversible from the popover via Re-arm.
public struct DefangNeedsReviewIntent: AppIntent {
    public static var title: LocalizedStringResource =
        "Defang downloads needing review"
    // IntentDescription requires a string literal — keep it one line.
    public static var description = IntentDescription("Rename every unsigned/unknown file in ~/Downloads to .quarantine so it can't launch on double-click. Reversible from the Quarantine popover via Re-arm.")
    public static var openAppWhenRun: Bool = true
    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        IntentBus.shared.defangNeedsReview()
        return .result()
    }
}
