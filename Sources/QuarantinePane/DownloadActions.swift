import Foundation

/// User-initiated, confirmable actions on a `~/Downloads` item.
///
/// Quarantine's scan is read-only; *these* are the only file-mutating
/// operations and every one is driven by an explicit click in the
/// popover (never automatic). Reversibility, in order of safety:
///
///  • `defang` ⇄ `rearm`   — pure rename, fully reversible
///  • `moveToTrash`         — recoverable from the user's Trash
///  • `deletePermanently`   — IRREVERSIBLE; the caller must have
///                            shown a destructive confirmation first
///
/// Every operation is hard-fenced to the Downloads directory so a
/// stale/forged path can never touch anything else.
enum DownloadActions {
    /// Appended to neutralise a file: a double-click on
    /// `installer.dmg.quarantine` can't mount or launch it. The
    /// rename is undone by `rearm`.
    static let suffix = ".quarantine"

    enum ActionError: LocalizedError {
        case outsideDownloads
        case alreadyDefanged
        case notDefanged
        case nameTaken(String)

        var errorDescription: String? {
            switch self {
            case .outsideDownloads:
                return "Refused: that file is outside ~/Downloads."
            case .alreadyDefanged:
                return "That file is already defanged."
            case .notDefanged:
                return "That file isn't a defanged item."
            case .nameTaken(let n):
                return "“\(n)” already exists — not overwriting it."
            }
        }
    }

    // MARK: Actions

    /// `installer.dmg` → `installer.dmg.quarantine`. Returns the new URL.
    @discardableResult
    static func defang(_ item: DownloadItem) throws -> URL {
        let src = try fenced(item)
        guard !item.isDefanged else { throw ActionError.alreadyDefanged }
        let dst = src.deletingLastPathComponent()
            .appendingPathComponent(item.name + suffix)
        guard !FileManager.default.fileExists(atPath: dst.path) else {
            throw ActionError.nameTaken(dst.lastPathComponent)
        }
        try FileManager.default.moveItem(at: src, to: dst)
        return dst
    }

    /// `installer.dmg.quarantine` → `installer.dmg`. Never overwrites
    /// an existing file — falls back to `… (re-armed)` names.
    @discardableResult
    static func rearm(_ item: DownloadItem) throws -> URL {
        let src = try fenced(item)
        guard item.isDefanged else { throw ActionError.notDefanged }
        let dir = src.deletingLastPathComponent()
        let original = String(item.name.dropLast(suffix.count))
        let dst = dir.appendingPathComponent(
            nonClobbering(original, in: dir)
        )
        try FileManager.default.moveItem(at: src, to: dst)
        return dst
    }

    /// Recoverable: into the user's Trash (not unlinked).
    static func moveToTrash(_ item: DownloadItem) throws {
        let url = try fenced(item)
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// IRREVERSIBLE. The UI must confirm before calling this.
    static func deletePermanently(_ item: DownloadItem) throws {
        let url = try fenced(item)
        try FileManager.default.removeItem(at: url)
    }

    // MARK: Guards

    /// The item's URL, but only if it really sits inside ~/Downloads.
    private static func fenced(_ item: DownloadItem) throws -> URL {
        let url = URL(fileURLWithPath: item.path)
        let root = DownloadsScanner.downloadsURL.standardizedFileURL.path
        let parent = url.deletingLastPathComponent()
            .standardizedFileURL.path
        guard parent == root || parent.hasPrefix(root + "/") else {
            throw ActionError.outsideDownloads
        }
        return url
    }

    /// First free name for `desired` in `dir`: `foo.dmg`, else
    /// `foo (re-armed).dmg`, `foo (re-armed 2).dmg`, …
    private static func nonClobbering(_ desired: String, in dir: URL) -> String {
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.appendingPathComponent(desired).path) {
            return desired
        }
        let ext = (desired as NSString).pathExtension
        let stem = (desired as NSString).deletingPathExtension
        var n = 1
        while true {
            let tag = n == 1 ? "(re-armed)" : "(re-armed \(n))"
            let cand = ext.isEmpty
                ? "\(stem) \(tag)"
                : "\(stem) \(tag).\(ext)"
            if !fm.fileExists(atPath: dir.appendingPathComponent(cand).path) {
                return cand
            }
            n += 1
        }
    }
}
