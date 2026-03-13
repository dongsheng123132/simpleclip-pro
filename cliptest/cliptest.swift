import XCTest
import SwiftData
@testable import SimpleClip

@MainActor
final class ClipboardItemTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: ClipboardItem.self, DailyDigest.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    func testSensitiveItemMarking() throws {
        let item = ClipboardItem(content: "联系 test@example.com", type: .text)
        item.isSensitive = true
        context.insert(item)
        try context.save()

        let descriptor = FetchDescriptor<ClipboardItem>()
        let items = try context.fetch(descriptor)

        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.first!.isSensitive)
    }

    func testCleanSensitiveItemsNow() throws {
        let monitor = ClipboardMonitor(modelContext: context)

        // Insert sensitive item (unpinned)
        let sensitive = ClipboardItem(content: "密码 password=abc", type: .text)
        sensitive.isSensitive = true
        context.insert(sensitive)

        // Insert normal item
        let normal = ClipboardItem(content: "Hello World", type: .text)
        context.insert(normal)
        try context.save()

        let deleted = monitor.cleanSensitiveItemsNow()
        XCTAssertEqual(deleted, 1)

        let remaining = try context.fetch(FetchDescriptor<ClipboardItem>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.content, "Hello World")
    }

    func testPinnedSensitiveItemNotCleaned() throws {
        let monitor = ClipboardMonitor(modelContext: context)

        // Insert pinned sensitive item
        let pinned = ClipboardItem(content: "sk-abcdefghijklmnopqrstuvwxyz", type: .text)
        pinned.isSensitive = true
        pinned.isPinned = true
        context.insert(pinned)
        try context.save()

        let deleted = monitor.cleanSensitiveItemsNow()
        XCTAssertEqual(deleted, 0)

        let remaining = try context.fetch(FetchDescriptor<ClipboardItem>())
        XCTAssertEqual(remaining.count, 1)
    }

    func testEncryptedContentStorage() throws {
        let item = ClipboardItem(content: "test@example.com 密码", type: .text)
        item.isSensitive = true
        // Simulate encryption as done by ClipboardMonitor
        if let encrypted = PIIDetector.encrypt(item.content) {
            item.encryptedContent = encrypted
            item.content = "[encrypted]"
        }
        context.insert(item)
        try context.save()

        let descriptor = FetchDescriptor<ClipboardItem>()
        let items = try context.fetch(descriptor)
        let fetched = items.first!

        XCTAssertEqual(fetched.content, "[encrypted]")
        XCTAssertNotNil(fetched.encryptedContent)
        XCTAssertEqual(fetched.decryptedContent, "test@example.com 密码")
    }

    func testDecryptedContentFallsBackToContent() throws {
        let item = ClipboardItem(content: "plain text", type: .text)
        context.insert(item)
        try context.save()

        let descriptor = FetchDescriptor<ClipboardItem>()
        let fetched = try context.fetch(descriptor).first!

        // No encryptedContent → decryptedContent returns content as-is
        XCTAssertEqual(fetched.decryptedContent, "plain text")
    }
}
