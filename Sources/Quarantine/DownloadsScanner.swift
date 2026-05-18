import Foundation
import CryptoKit
import UniformTypeIdentifiers

/// One inspected item in ~/Downloads with its full trust posture.
struct DownloadItem: Identifiable, Hashable {
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

            let size = Int64(values?.fileSize ?? directorySize(url))
            let added = values?.addedToDirectoryDate
                ?? values?.contentModificationDate ?? Date.distantPast
            let typeDesc = values?.contentType?.localizedDescription
                ?? url.pathExtension.uppercased()

            let (agent, origin) = quarantine(url)
            let hash = sha256Hex(url)
            let sig = Signature.inspect(url)

            items.append(DownloadItem(
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
            ))
        }
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
