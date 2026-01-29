import Foundation
import AppKit
import SwiftData

enum ClipboardType: String, Codable {
    case text
    case image
    case url
}

@Model
final class ClipboardItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var content: String          // 文本内容或图片路径
    var type: ClipboardType
    var timestamp: Date
    var isPinned: Bool           // 是否固定

    init(content: String, type: ClipboardType) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.isPinned = false
    }

    // 显示用的预览文本（不持久化）
    var preview: String {
        switch type {
        case .text, .url:
            return String(content.prefix(300))
        case .image:
            return "🖼️ 图片"
        }
    }

    // 格式化时间（不持久化）
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
