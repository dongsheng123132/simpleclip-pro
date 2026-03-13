import Foundation
import CryptoKit

/// Unified PII detection and redaction for SimpleClip.
/// Used by ClipboardMonitor (detection), LifeClipExporter & DailySummaryService (redaction).
enum PIIDetector {

    // MARK: - Patterns

    private static let patterns: [(NSRegularExpression, String)] = {
        let defs: [(String, String)] = [
            // Email
            ("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "[email]"),
            // Phone (international + Chinese)
            ("(?:\\+?\\d{1,3}[- ]?)?1[3-9]\\d{9}|\\(\\d{3}\\)\\s*\\d{3}[- ]?\\d{4}|\\d{3}[- ]\\d{3}[- ]\\d{4}", "[phone]"),
            // Credit card
            ("\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b", "[card]"),
            // IP addresses
            ("\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b", "[ip]"),
            // API keys
            ("sk-[A-Za-z0-9]{20,}", "[api-key]"),
            ("ghp_[A-Za-z0-9]{36}", "[api-key]"),
            ("gho_[A-Za-z0-9]{36}", "[api-key]"),
            ("glpat-[A-Za-z0-9_-]{20,}", "[api-key]"),
            ("Bearer [A-Za-z0-9._-]{20,}", "[token]"),
            // URL token/key parameters
            ("token=[A-Za-z0-9._-]{10,}", "token=[redacted]"),
            ("API_KEY=[^\\s&\"']{5,}", "API_KEY=[redacted]"),
            // Chinese ID card (18 digits)
            ("\\b\\d{6}(?:19|20)\\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\\d|3[01])\\d{3}[\\dXx]\\b", "[id_card]"),
            // Password / secret assignments
            ("(?i)(password|secret|token|api_key)\\s*[:=]\\s*\\S+", "[secret]"),
        ]
        return defs.compactMap { pattern, replacement in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (regex, replacement)
        }
    }()

    /// Returns true if the text contains any sensitive pattern.
    static func containsSensitiveContent(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        for (regex, _) in patterns {
            if regex.firstMatch(in: text, range: range) != nil {
                return true
            }
        }
        return false
    }

    /// Redacts sensitive content, replacing matches with placeholders.
    static func redact(_ text: String) -> String {
        var result = text
        for (regex, replacement) in patterns {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
        }
        return result
    }

    // MARK: - AES-GCM Encryption (for sensitive items at rest)

    /// Encrypts text using AES-GCM with the Keychain-stored key.
    /// Returns combined nonce + ciphertext + tag, or nil on failure.
    static func encrypt(_ text: String) -> Data? {
        guard let plaintext = text.data(using: .utf8) else { return nil }
        let key = KeychainHelper.getOrCreateEncryptionKey()
        guard let sealedBox = try? AES.GCM.seal(plaintext, using: key) else { return nil }
        return sealedBox.combined
    }

    /// Decrypts data that was encrypted with `encrypt(_:)`.
    /// Returns the original string, or nil if decryption fails.
    static func decrypt(_ data: Data) -> String? {
        let key = KeychainHelper.getOrCreateEncryptionKey()
        guard let sealedBox = try? AES.GCM.SealedBox(combined: data),
              let plaintext = try? AES.GCM.open(sealedBox, using: key) else { return nil }
        return String(data: plaintext, encoding: .utf8)
    }
}
