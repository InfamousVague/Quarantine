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
