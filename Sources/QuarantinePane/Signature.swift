import Foundation

/// Code-signing / Gatekeeper trust posture for a downloaded file.
enum TrustLevel: String {
    case notarized      // Developer ID + notarized, Gatekeeper accepts
    case signed         // validly signed but not notarized / not accepted
    case unsigned       // unsigned or Gatekeeper rejects
    case notApplicable  // plain document — signing doesn't apply
    case unknown        // couldn't determine
}

struct SignatureInfo {
    var trust: TrustLevel
    var summary: String        // short human label for the badge tooltip
    var authority: String?     // leaf authority / "signed by"
    var teamID: String?
}

enum Signature {
    /// Extensions worth assessing with spctl/codesign. Everything else is a doc.
    private static let assessable: Set<String> = [
        "app", "dmg", "pkg", "mpkg", "command", "tool", "kext", "bundle"
    ]

    static func inspect(_ url: URL) -> SignatureInfo {
        let ext = url.pathExtension.lowercased()
        let isExecBinary = ext.isEmpty && isExecutable(url)

        guard assessable.contains(ext) || isExecBinary else {
            return SignatureInfo(trust: .notApplicable,
                                  summary: "document — signing n/a",
                                  authority: nil, teamID: nil)
        }

        let spctlType = (ext == "dmg" || ext == "pkg" || ext == "mpkg")
            ? "install" : "open"
        let assess = run("/usr/sbin/spctl",
                         ["--assess", "--type", spctlType, "-vv", url.path])
        let assessText = assess.out + assess.err

        let cs = run("/usr/bin/codesign", ["-dv", "--verbose=2", url.path])
        let csText = cs.out + cs.err
        let authority = firstMatch(in: csText, prefix: "Authority=")
        let teamID = firstMatch(in: csText, prefix: "TeamIdentifier=")
            .flatMap { $0 == "not set" ? nil : $0 }

        let accepted = assess.status == 0 || assessText.contains("accepted")
        let notarized = assessText.localizedCaseInsensitiveContains("Notarized")
            || assessText.localizedCaseInsensitiveContains("source=Notarized")
        let hasSignature = !csText.contains("code object is not signed")
            && cs.status == 0

        let trust: TrustLevel
        let summary: String
        if accepted && notarized {
            trust = .notarized
            summary = "Developer ID, notarized"
        } else if accepted && hasSignature {
            trust = .signed
            summary = "signed & accepted"
        } else if hasSignature {
            trust = .signed
            summary = "signed, not notarized"
        } else {
            trust = .unsigned
            summary = "unsigned / rejected"
        }

        return SignatureInfo(trust: trust, summary: summary,
                             authority: authority, teamID: teamID)
    }

    private static func isExecutable(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
              !isDir.boolValue else { return false }
        return FileManager.default.isExecutableFile(atPath: url.path)
    }

    private static func firstMatch(in text: String, prefix: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count))
            }
        }
        return nil
    }

    /// Run a tool, capture stdout/stderr/exit. Empty on failure (never throws).
    @discardableResult
    static func run(_ path: String, _ args: [String]) -> (out: String, err: String, status: Int32) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        do {
            try proc.run()
        } catch {
            return ("", "", -1)
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return (
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? "",
            proc.terminationStatus
        )
    }
}
