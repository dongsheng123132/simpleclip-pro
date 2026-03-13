import XCTest
@testable import SimpleClip

final class PIIDetectorTests: XCTestCase {

    // MARK: - containsSensitiveContent — positive (should return true)

    func testDetectsEmail() {
        XCTAssertTrue(PIIDetector.containsSensitiveContent("联系我 test@example.com 谢谢"))
    }

    func testDetectsChinesePhone() {
        XCTAssertTrue(PIIDetector.containsSensitiveContent("我的号码 13812345678"))
    }

    func testDetectsUSPhone() {
        XCTAssertTrue(PIIDetector.containsSensitiveContent("Call me at 415-555-1234"))
    }

    func testDetectsCreditCard() {
        XCTAssertTrue(PIIDetector.containsSensitiveContent("卡号 4111 1111 1111 1111"))
    }

    func testDetectsOpenAIKey() {
        XCTAssertTrue(PIIDetector.containsSensitiveContent("sk-abc123def456ghi789jkl012mno"))
    }

    func testDetectsGitHubToken() {
        XCTAssertTrue(PIIDetector.containsSensitiveContent("ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"))
    }

    func testDetectsBearerToken() {
        XCTAssertTrue(PIIDetector.containsSensitiveContent("Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5c"))
    }

    func testDetectsPasswordAssignment() {
        XCTAssertTrue(PIIDetector.containsSensitiveContent("password=myS3cretP@ss"))
    }

    func testDetectsSecretAssignment() {
        XCTAssertTrue(PIIDetector.containsSensitiveContent("secret: sk_live_xxxxx"))
    }

    func testDetectsAPIKeyAssignment() {
        XCTAssertTrue(PIIDetector.containsSensitiveContent("API_KEY=abcdef12345"))
    }

    // MARK: - containsSensitiveContent — negative (should return false)

    func testPlainText() {
        XCTAssertFalse(PIIDetector.containsSensitiveContent("Hello World"))
    }

    func testPlainURL() {
        XCTAssertFalse(PIIDetector.containsSensitiveContent("https://github.com/dongsheng123132"))
    }

    func testDateString() {
        XCTAssertFalse(PIIDetector.containsSensitiveContent("2026年3月13日"))
    }

    func testPriceString() {
        XCTAssertFalse(PIIDetector.containsSensitiveContent("价格 ¥199.00"))
    }

    func testShortSKPrefix() {
        XCTAssertFalse(PIIDetector.containsSensitiveContent("sk-short"))
    }

    // MARK: - redact — replacement verification

    func testRedactEmail() {
        let result = PIIDetector.redact("联系 test@example.com")
        XCTAssertEqual(result, "联系 [email]")
    }

    func testRedactPhone() {
        let result = PIIDetector.redact("电话 13812345678")
        XCTAssertEqual(result, "电话 [phone]")
    }

    func testRedactCreditCard() {
        let result = PIIDetector.redact("卡号 4111-1111-1111-1111")
        XCTAssertEqual(result, "卡号 [card]")
    }

    func testRedactAPIKey() {
        let result = PIIDetector.redact("sk-abcdefghijklmnopqrstuvwxyz")
        XCTAssertEqual(result, "[api-key]")
    }

    func testRedactPassword() {
        let result = PIIDetector.redact("password=secret123")
        XCTAssertEqual(result, "[secret]")
    }

    func testRedactCleanText() {
        let result = PIIDetector.redact("Hello World")
        XCTAssertEqual(result, "Hello World")
    }

    func testRedactMixed() {
        let result = PIIDetector.redact("邮箱 a@b.com 电话 13912345678")
        XCTAssertTrue(result.contains("[email]"))
        XCTAssertTrue(result.contains("[phone]"))
        XCTAssertFalse(result.contains("a@b.com"))
        XCTAssertFalse(result.contains("13912345678"))
    }

    // MARK: - Encrypt / Decrypt

    func testEncryptDecryptRoundTrip() {
        let original = "test@example.com 密码 password=abc123"
        guard let encrypted = PIIDetector.encrypt(original) else {
            XCTFail("Encryption returned nil")
            return
        }
        // Encrypted data should not contain the original plaintext
        let encryptedString = String(data: encrypted, encoding: .utf8) ?? ""
        XCTAssertFalse(encryptedString.contains("test@example.com"))

        guard let decrypted = PIIDetector.decrypt(encrypted) else {
            XCTFail("Decryption returned nil")
            return
        }
        XCTAssertEqual(decrypted, original)
    }

    func testDecryptInvalidDataReturnsNil() {
        let garbage = Data("not-encrypted".utf8)
        XCTAssertNil(PIIDetector.decrypt(garbage))
    }

    func testEncryptProducesDifferentCiphertext() {
        let text = "sensitive data 13812345678"
        let a = PIIDetector.encrypt(text)
        let b = PIIDetector.encrypt(text)
        // AES-GCM uses random nonce, so two encryptions of the same text should differ
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertNotEqual(a, b)
    }
}
