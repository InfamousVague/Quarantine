import Foundation
import CryptoKit
import UniformTypeIdentifiers

/// One inspected item in ~/Downloads with its full trust posture.
struct DownloadItem: Identifiable, Hashable, Sendable {
    let path: String
    let name: String
    let size: Int64
    let dateAdded: Date
    let typeDescription: String
    let sha256: String
    let quarantineAgent: String?
    let originURL: String?
    let trust: TrustLevel
    let trustSummary: String
    let authority: String?
    let teamID: String?

    /// Stable identity: path + size (a replaced file re-notifies).
    var id: String { "\(path)#\(size)" }
    var shortHash: String { String(sha256.prefix(16)) }

    /// True once Quarantine has neutralised the file by appending the
    /// `.quarantine` suffix (so a double-click can't launch it).
    var isDefanged: Bool { name.hasSuffix(DownloadActions.suffix) }

    /// The name without the defang suffix — what the user recognises.
    var displayName: String {
        isDefanged ? String(name.dropLast(DownloadActions.suffix.count)) : name
    }

    static func == (lhs: DownloadItem, rhs: DownloadItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum DownloadsScanner {
    static var downloadsURL: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
    }

    /// Names/suffixes never shown: metadata + in-progress downloads.
    private static let ignoredNames: Set<String> = [".DS_Store", ".localized", "desktop.ini"]
    private static let inProgressSuffixes = [".download", ".crdownload", ".part", ".partial"]

    /// Content-fingerprint cache. Hashing every file and shelling out
    /// to `spctl`/`codesign` is expensive; the 5 s poll repeated that
    /// for unchanged files forever (~8% CPU). A file whose path, size
    /// and modification date are unchanged since the last scan is
    /// reused verbatim, so a steady Downloads folder costs only a
    /// directory `stat` per tick (~0% CPU). Thread-safe: `scan()` runs
    /// on a detached task and scans can briefly overlap.
    private final class ScanCache: @unchecked Sendable {
        private let lock = NSLock()
        private var map: [String: DownloadItem] = [:]
        func get(_ key: String) -> DownloadItem? {
            lock.lock(); defer { lock.unlock() }; return map[key]
        }
        func set(_ key: String, _ item: DownloadItem) {
            lock.lock(); defer { lock.unlock() }; map[key] = item
        }
        /// Drop entries for files that no longer exist (bounds memory).
        func retain(_ keys: Set<String>) {
            lock.lock(); defer { lock.unlock() }
            map = map.filter { keys.contains($0.key) }
        }
    }
    private static let scanCache = ScanCache()

    /// Synchronous scan — call from a detached task. Newest first.
    static func scan() -> [DownloadItem] {
        let fm = FileManager.default
        let dir = downloadsURL
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isDirectoryKey, .fileSizeKey,
            .addedToDirectoryDateKey, .contentModificationDateKey,
            .contentTypeKey, .isPackageKey
        ]
        guard let entries = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [DownloadItem] = []
        var liveKeys = Set<String>()
        for url in entries {
            let name = url.lastPathComponent
            if name.hasPrefix(".") || ignoredNames.contains(name) { continue }
            if inProgressSuffixes.contains(where: { name.hasSuffix($0) }) { continue }

            let values = try? url.resourceValues(forKeys: Set(keys))
            // Accept regular files and .app/.pkg packages; skip plain folders.
            let isPackage = values?.isPackage ?? false
            let isDir = values?.isDirectory ?? false
            let isFile = values?.isRegularFile ?? false
            if !isFile && !(isDir && isPackage) { continue }

            // Cheap fingerprint from stat alone (no hashing / no
            // directory walk / no subprocess). Unchanged file → reuse.
            let rawSize = values?.fileSize ?? -1
            let mtime = values?.contentModificationDate ?? Date.distantPast
            let fingerprint = "\(url.path)#\(rawSize)#\(mtime.timeIntervalSinceReferenceDate)"
            liveKeys.insert(fingerprint)
            if let cached = scanCache.get(fingerprint) {
                items.append(cached)
                continue
            }

            // New or changed file: do the expensive work once, cache it.
            let size = Int64(values?.fileSize ?? directorySize(url))
            let added = values?.addedToDirectoryDate
                ?? values?.contentModificationDate ?? Date.distantPast
            let typeDesc = values?.contentType?.localizedDescription
                ?? url.pathExtension.uppercased()

            let (agent, origin) = quarantine(url)
            let hash = sha256Hex(url)
            let sig = Signature.inspect(url)

            let item = DownloadItem(
                path: url.path,
                name: name,
                size: size,
                dateAdded: added,
                typeDescription: typeDesc,
                sha256: hash,
                quarantineAgent: agent,
                originURL: origin,
                trust: sig.trust,
                trustSummary: sig.summary,
                authority: sig.authority,
                teamID: sig.teamID
            )
            scanCache.set(fingerprint, item)
            items.append(item)
        }
        scanCache.retain(liveKeys)
        return items.sorted { $0.dateAdded > $1.dateAdded }
    }

    // MARK: - Quarantine xattr

    /// `com.apple.quarantine` is `flags;timestamp;agent;UUID-or-URL`.
    /// We surface the agent (e.g. "Safari") and the origin/referrer URL.
    static func quarantine(_ url: URL) -> (agent: String?, origin: String?) {
        let r = Signature.run("/usr/bin/xattr",
                              ["-p", "com.apple.quarantine", url.path])
        let raw = r.out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard r.status == 0, !raw.isEmpty else { return (nil, nil) }

        let fields = raw.components(separatedBy: ";")
        let agent = fields.count > 2
            ? fields[2].trimmingCharacters(in: .whitespaces) : nil
        var origin: String? = nil
        if fields.count > 3 {
            let f = fields[3].trimmingCharacters(in: .whitespaces)
            if f.lowercased().hasPrefix("http") || f.lowercased().hasPrefix("ftp") {
                origin = f
            }
        }
        return (agent?.isEmpty == true ? nil : agent, origin)
    }

    // MARK: - SHA-256 (streamed)

    static func sha256Hex(_ url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = (try? handle.read(upToCount: 1 << 20)) ?? Data()
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func directorySize(_ url: URL) -> Int {
        guard let en = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        var total = 0
        for case let f as URL in en {
            total += (try? f.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        }
        return total
    }
}
