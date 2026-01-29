import Foundation
import SwiftData

@Model
final class DailyDigest: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date       // 当日 0 点（用于去重与展示）
    var summary: String  // AI 生成的摘要
    var itemCount: Int   // 当日参与统计的条数

    init(date: Date, summary: String, itemCount: Int) {
        self.id = UUID()
        self.date = date
        self.summary = summary
        self.itemCount = itemCount
    }
}
