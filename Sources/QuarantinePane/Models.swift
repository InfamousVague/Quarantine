import Foundation
import Observation
import AppKit
import QuarantineShared

@MainActor
@Observable
final class QuarantineStore {
    var items: [DownloadItem] = []
    /// SHA-256 → VirusTotal verdict (populated lazily, best-effort).
    var vtVerdicts: [String: VirusTotal.Verdict] = [:]
    var lastError: String?
    /// File path the user asked to jump to (set from a notification click).
    var focusedKey: String?

    var vtConfigured: Bool { VirusTotal.isConfigured }
    var downloadsPath: String { DownloadsScanner.downloadsURL.path }

    @ObservationIgnored private var seenKeys: Set<String> = []
    @ObservationIgnored private var firstScanDone = false
    @ObservationIgnored private var vtRequested: Set<String> = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var scanning = false

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        // Don't stack scans: if the previous tick's scan is still
        // running (e.g. first-time hashing of a big download), skip
        // this one rather than piling detached tasks on top.
        guard !scanning else { return }
        scanning = true
        Task.detached {
            let scanned = DownloadsScanner.scan()
            await MainActor.run {
                self.scanning = false
                self.apply(scanned)
            }
        }
    }

    private func apply(_ scanned: [DownloadItem]) {
        items = scanned
        let current = Set(scanned.map { $0.id })

        if firstScanDone {
            // A defanged file is one we renamed ourselves — its new
            // path looks "new" to the diff, but it must never alert.
            let defanged = Set(scanned.filter { $0.isDefanged }.map { $0.id })
            let newKeys = current.subtracting(seenKeys).subtracting(defanged)
            if newKeys.count > 5 {
                Notifier.postSummary(count: newKeys.count)
            } else {
                for item in scanned where newKeys.contains(item.id) {
                    Notifier.postNewDownload(
                        key: item.path,
                        name: item.name,
                        trust: item.trust,
                        summary: item.trustSummary
                    )
                }
            }
        }
        seenKeys = current
        firstScanDone = true
        publishSharedSnapshot()

        // Best-effort VirusTotal enrichment for items we haven't queried.
        guard VirusTotal.isConfigured else { return }
        for item in scanned where !item.sha256.isEmpty
            && !vtRequested.contains(item.sha256) {
            vtRequested.insert(item.sha256)
            let hash = item.sha256
            Task.detached {
                if let verdict = await VirusTotal.lookup(sha256: hash) {
                    await MainActor.run { self.vtVerdicts[hash] = verdict }
                }
            }
        }
    }

    // MARK: - VirusTotal key management

    var vtEnvManaged: Bool { VTKeyStore.isEnvManaged }
    func currentVTKey() -> String { VTKeyStore.keychainKey ?? "" }
    func validateVTKey(_ key: String) async -> Bool { await VirusTotal.validate(key) }

    func saveVTKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        VTKeyStore.save(trimmed)
        vtKeyChanged()
    }

    func clearVTKey() {
        VTKeyStore.clear()
        vtKeyChanged()
    }

    /// Re-query VirusTotal for everything now that the key changed.
    private func vtKeyChanged() {
        vtRequested.removeAll()
        vtVerdicts.removeAll()
        refresh()
    }

    func revealInFinder(_ item: DownloadItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
    }

    func copyHash(_ item: DownloadItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.sha256, forType: .string)
    }

    // MARK: - User-initiated file actions
    //
    // All four are explicit popover clicks (never automatic). They run
    // off the main actor, surface failures in `lastError`, and trigger
    // a rescan so the list reflects reality immediately.

    /// Rename so a double-click can't launch/mount it (reversible).
    func defang(_ item: DownloadItem) { perform { try DownloadActions.defang(item) } }

    /// Undo `defang` — restore the original name (reversible).
    func rearm(_ item: DownloadItem) { perform { try DownloadActions.rearm(item) } }

    /// Recoverable: move the file to the user's Trash.
    func moveToTrash(_ item: DownloadItem) { perform { try DownloadActions.moveToTrash(item) } }

    /// IRREVERSIBLE — only call after a destructive confirmation.
    func deletePermanently(_ item: DownloadItem) {
        perform { try DownloadActions.deletePermanently(item) }
    }

    private func perform(_ work: @escaping @Sendable () throws -> Void) {
        Task.detached {
            do {
                try work()
                await MainActor.run {
                    self.lastError = nil
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    /// Publish a compact widget-facing snapshot of ~/Downloads'
    /// trust posture. SharedQuarantineStore writes the JSON to the
    /// Group Container and kicks WidgetKit to reload its timeline.
    private func publishSharedSnapshot() {
        func badge(_ t: TrustLevel) -> SharedQuarantine.Badge {
            switch t {
            case .notarized: return .notarized
            case .signed: return .signed
            case .unsigned: return .unsigned
            case .notApplicable: return .notApplicable
            case .unknown: return .unknown
            }
        }
        let needs = items.filter {
            $0.trust == .unsigned || $0.trust == .unknown
        }.count
        let recent = items
            .sorted { $0.dateAdded > $1.dateAdded }
            .prefix(3)
            .map { SharedQuarantine.Row(
                name: $0.name, badge: badge($0.trust)) }
        let snap = SharedQuarantine(
            totalCount: items.count,
            needsReviewCount: needs,
            recent: Array(recent),
            sampledAt: Date()
        )
        SharedQuarantineStore.write(snap)
    }
}
