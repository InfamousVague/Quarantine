import Foundation

/// Optional VirusTotal lookup by SHA-256. Fully opt-in (needs `VT_API_KEY`),
/// async and non-blocking — any failure is swallowed and reported as nil.
enum VirusTotal {
    static var isConfigured: Bool { VTKeyStore.resolvedKey != nil }

    /// Cheap auth check: a HEAD-ish GET of the empty-file hash. 200/404 ⇒ the
    /// key works (file known / unknown); 401/403 ⇒ bad key. Network failure is
    /// treated as "can't tell" → valid, so we don't block setup while offline.
    static func validate(_ key: String) async -> Bool {
        let emptySHA = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        guard !key.isEmpty,
              let url = URL(string: "https://www.virustotal.com/api/v3/files/\(emptySHA)")
        else { return false }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "x-apikey")
        request.timeoutInterval = 12
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse
        else { return true }
        return http.statusCode != 401 && http.statusCode != 403
    }

    struct Verdict {
        let malicious: Int
        let suspicious: Int
        let harmless: Int
        let undetected: Int
        var flagged: Bool { malicious > 0 || suspicious > 0 }
    }

    /// Look up a file's report. Returns nil if unconfigured, not yet seen by
    /// VT (404), or on any network/parse error — never throws.
    static func lookup(sha256: String) async -> Verdict? {
        guard let key = VTKeyStore.resolvedKey,
              let url = URL(string: "https://www.virustotal.com/api/v3/files/\(sha256)")
        else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "x-apikey")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200
            else { return nil }
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard
                let dataObj = root?["data"] as? [String: Any],
                let attrs = dataObj["attributes"] as? [String: Any],
                let stats = attrs["last_analysis_stats"] as? [String: Any]
            else { return nil }
            func n(_ k: String) -> Int { (stats[k] as? Int) ?? 0 }
            return Verdict(
                malicious: n("malicious"),
                suspicious: n("suspicious"),
                harmless: n("harmless"),
                undetected: n("undetected")
            )
        } catch {
            return nil
        }
    }
}
