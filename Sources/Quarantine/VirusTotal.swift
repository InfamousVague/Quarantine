import Foundation

/// Optional VirusTotal lookup by SHA-256. Fully opt-in (needs `VT_API_KEY`),
/// async and non-blocking — any failure is swallowed and reported as nil.
enum VirusTotal {
    static var isConfigured: Bool {
        !(ProcessInfo.processInfo.environment["VT_API_KEY"] ?? "").isEmpty
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
        guard let key = ProcessInfo.processInfo.environment["VT_API_KEY"],
              !key.isEmpty,
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
