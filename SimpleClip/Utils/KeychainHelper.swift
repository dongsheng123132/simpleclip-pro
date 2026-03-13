import Foundation
import Security
import CryptoKit

/// Manages an AES-256 symmetric key in the macOS Keychain.
/// The key is bound to the app's bundle ID — other apps cannot access it.
enum KeychainHelper {

    private static let service = "com.hequbing.SimpleClip.encryption"
    private static let account = "aes256-key"

    /// Returns the existing encryption key or generates a new one and stores it in Keychain.
    static func getOrCreateEncryptionKey() -> SymmetricKey {
        if let existing = loadKey() {
            return existing
        }
        let key = SymmetricKey(size: .bits256)
        saveKey(key)
        return key
    }

    // MARK: - Private

    private static func loadKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private static func saveKey(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete any existing item first to avoid errSecDuplicateItem
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("⚠️ Keychain save failed: \(status)")
        }
    }
}
