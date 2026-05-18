import Foundation
import Security

/// Persisted VirusTotal API key. Stored in the login Keychain (a credential,
/// not a pref) so a Finder-launched menu-bar app can actually find it —
/// unlike a shell env var, which `.app` bundles never inherit.
///
/// Resolution order: the `VT_API_KEY` environment variable always wins (so
/// `VT_API_KEY=… swift run` and CI keep working), otherwise the Keychain.
enum VTKeyStore {
    private static let service = "com.mattssoftware.quarantine"
    private static let account = "VT_API_KEY"

    static var isEnvManaged: Bool {
        !(ProcessInfo.processInfo.environment["VT_API_KEY"] ?? "").isEmpty
    }

    /// The key the app should actually use, or nil if none configured.
    static var resolvedKey: String? {
        if let env = ProcessInfo.processInfo.environment["VT_API_KEY"], !env.isEmpty {
            return env
        }
        let stored = keychainKey
        return (stored?.isEmpty == false) ? stored : nil
    }

    /// The user-managed Keychain value (independent of any env override).
    static var keychainKey: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func clear() -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(base as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
