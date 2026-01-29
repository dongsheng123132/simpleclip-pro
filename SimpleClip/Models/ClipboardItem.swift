import Foundation
import AppKit
import SwiftData
import CryptoKit

enum ClipboardType: String, Codable {
    case text
    case image
    case url
}

@Model
final class ClipboardItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var content: String
    var type: ClipboardType
    var timestamp: Date
    var isPinned: Bool
    @Attribute(.unique) var contentHash: String

    init(content: String, type: ClipboardType) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.isPinned = false
        self.contentHash = Self.sha256Hex(content)
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

    private static func sha256Hex(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
