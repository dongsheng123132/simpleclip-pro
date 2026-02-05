import Foundation
import AppKit
import SwiftData
import CryptoKit
import QuickLook
import UniformTypeIdentifiers

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
    var contentHash: String

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
    
    // Quick Look 预览支持
    var quickLookItem: QuickLookItem {
        switch type {
        case .image:
            return QuickLookItem(url: URL(fileURLWithPath: content), title: "图片预览")
        case .url:
            return QuickLookItem(text: content, title: "链接")
        case .text:
            return QuickLookItem(text: content, title: "文本")
        }
    }
}

// Quick Look 预览项
struct QuickLookItem: Identifiable {
    let id = UUID()
    let url: URL?
    let text: String?
    let title: String
    
    init(url: URL, title: String) {
        self.url = url
        self.text = nil
        self.title = title
    }
    
    init(text: String, title: String) {
        self.url = nil
        self.text = text
        self.title = title
    }
    
    var previewItemURL: URL? { url }
}
