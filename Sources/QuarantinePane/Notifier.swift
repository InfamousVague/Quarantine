import Foundation
import UserNotifications

/// Thin wrapper over UserNotifications for "a new download appeared" alerts.
enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert]) { _, _ in }
    }

    static func postNewDownload(key: String, name: String,
                                trust: TrustLevel, summary: String) {
        let content = UNMutableNotificationContent()
        switch trust {
        case .unsigned:
            content.title = "⚠️ \(name) — \(summary)"
            content.body = "Risky download. Click to inspect it in Quarantine."
        case .notarized:
            content.title = "Downloaded: \(name)"
            content.body = "\(summary). Click to view it in Quarantine."
        default:
            content.title = "Downloaded: \(name)"
            content.body = "\(summary). Click to inspect it in Quarantine."
        }
        content.userInfo = ["quarantineKey": key, "suitePane": "quarantine", "suiteFocus": key]
        send(id: "dl-\(key.hashValue)", content: content)
    }

    static func postSummary(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(count) new downloads"
        content.body = "Click to inspect them in Quarantine."
        send(id: "dl-burst-\(Int(Date().timeIntervalSince1970))", content: content)
    }

    private static func send(id: String, content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
