import XCTest
import SwiftData
@testable import SimpleClip

@MainActor
final class SimpleClipTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var monitor: ClipboardMonitor!

    override func setUpWithError() throws {
        // 使用内存数据库进行测试
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: ClipboardItem.self, DailyDigest.self, configurations: config)
        context = container.mainContext
        monitor = ClipboardMonitor(modelContext: context)
    }

    override func tearDownWithError() throws {
        monitor = nil
        context = nil
        container = nil
    }

    func testAddItem() throws {
        // 测试添加文本
        let item = ClipboardItem(content: "Test Content", type: .text)
        context.insert(item)
        
        let descriptor = FetchDescriptor<ClipboardItem>()
        let items = try context.fetch(descriptor)
        
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "Test Content")
    }
    
    func testDeduplication() throws {
        // 测试去重逻辑
        let item1 = ClipboardItem(content: "Duplicate", type: .text)
        context.insert(item1)
        try context.save()
        
        // 模拟 Monitor 的去重检查
        let newItemContent = "Duplicate"
        var descriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 1
        
        if let lastItem = try? context.fetch(descriptor).first, lastItem.content == newItemContent {
            // Should skip
        } else {
            let item2 = ClipboardItem(content: newItemContent, type: .text)
            context.insert(item2)
        }
        
        let allItems = try context.fetch(FetchDescriptor<ClipboardItem>())
        XCTAssertEqual(allItems.count, 1, "应该只有一个条目")
    }
    
    func testInfiniteStorage() throws {
        // 验证没有数量限制
        for i in 0..<100 {
            let item = ClipboardItem(content: "Item \(i)", type: .text)
            context.insert(item)
        }
        
        let count = try context.fetchCount(FetchDescriptor<ClipboardItem>())
        XCTAssertEqual(count, 100)
    }
}
