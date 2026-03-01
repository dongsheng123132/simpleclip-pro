import Foundation
import AppKit
import Combine
import ApplicationServices
import SwiftData
import CryptoKit

@MainActor
final class ClipboardMonitor: NSObject, ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastActiveApp: NSRunningApplication?
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.lastChangeCount = NSPasteboard.general.changeCount
        super.init()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func handleAppActivation(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastActiveApp = app
        }
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.checkClipboard()
            }
        }
        timer?.tolerance = 0.5
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        let pasteboard = NSPasteboard.general

        // 尝试多种方式读取字符串内容
        var content: String? = nil
        
        // 1. 优先尝试读取普通字符串
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            content = string
        }
        // 2. 尝试读取 URL 类型
        else if let urlString = pasteboard.string(forType: .URL), !urlString.isEmpty {
            content = urlString
        }
        // 3. 尝试读取 public.url
        else if let types = pasteboard.types {
            for type in types {
                if type.rawValue.contains("url") || type.rawValue.contains("URL") {
                    if let data = pasteboard.data(forType: type),
                       let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii),
                       !string.isEmpty {
                        content = string
                        break
                    }
                }
            }
        }
        
        // 处理文本/URL
        if let string = content {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            let type: ClipboardType = isValidURL(trimmed) ? .url : .text
            addItem(ClipboardItem(content: trimmed, type: type))
        }
        // 处理图片
        else if let image = pasteboard.data(forType: .tiff) {
            if let (imagePath, imageHash) = saveImageWithHash(image) {
                addItem(ClipboardItem(content: imagePath, type: .image, imageContentHash: imageHash))
            }
        }
    }
    
    /// 更完善的 URL 检测
    private func isValidURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 使用 NSURL 的检测
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count))
        
        // 如果整个字符串是一个链接
        if let match = matches?.first, match.range.length == trimmed.utf16.count {
            return true
        }
        
        // 备用检测：检查 scheme 和 host
        if let url = URL(string: trimmed),
           let scheme = url.scheme,
           scheme.hasPrefix("http") || scheme == "https" || scheme == "ftp" || scheme == "mailto" || scheme == "file" {
            if url.host != nil && !url.host!.isEmpty {
                return true
            }
        }
        
        return false
    }

    private func addItem(_ item: ClipboardItem) {
        // 图片类型使用 imageContentHash 去重，文本/URL 使用 contentHash 去重
        let hashValue: String
        let predicate: Predicate<ClipboardItem>
        
        if item.type == .image, let imgHash = item.imageContentHash {
            hashValue = imgHash
            predicate = #Predicate<ClipboardItem> { row in row.imageContentHash == hashValue }
        } else {
            hashValue = item.contentHash
            predicate = #Predicate<ClipboardItem> { row in row.contentHash == hashValue }
        }
        
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: predicate,
            sortBy: []
        )
        descriptor.fetchLimit = 1
        
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                // 重复内容：更新时间戳 + 复制次数 +1
                existing.timestamp = Date()
                existing.copyCount += 1
                try modelContext.save()
                NSLog("🔄 检测到重复内容(第\(existing.copyCount)次): \(existing.preview)")
                return
            }
            modelContext.insert(item)
            try modelContext.save()
            NSLog("✅ 添加新剪贴项: \(item.preview)")
        } catch {
            NSLog("❌ 添加剪贴项失败: \(error.localizedDescription)")
        }
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.type {
        case .text, .url:
            pasteboard.setString(item.content, forType: .string)
        case .image:
            if FileManager.default.fileExists(atPath: item.content) {
                if let image = NSImage(contentsOfFile: item.content) {
                    pasteboard.writeObjects([image])
                }
            }
        }
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func copyAndPaste(_ item: ClipboardItem) {
        copyToClipboard(item)
        pasteToFrontmostApp()
    }

    private func pasteToFrontmostApp() {
        if let app = lastActiveApp {
            app.activate(options: [])
            usleep(100000)
        } else {
            NSApp.hide(nil)
            usleep(100000)
        }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    func deleteItem(_ item: ClipboardItem) {
        modelContext.delete(item)
        do {
            try modelContext.save()
        } catch {
            NSLog("❌ 删除剪贴项失败: \(error.localizedDescription)")
        }
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        do {
            try modelContext.save()
        } catch {
            NSLog("❌ 更新固定状态失败: \(error.localizedDescription)")
            item.isPinned.toggle()
        }
    }

    func clearHistory() {
        do {
            try modelContext.delete(model: ClipboardItem.self, where: #Predicate { !$0.isPinned })
            try modelContext.save()
        } catch {
            print("Failed to clear history: \(error)")
        }
    }

    private func saveImageWithHash(_ imageData: Data) -> (path: String, hash: String)? {
        let fileManager = FileManager.default
        
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let clipboardDir = appSupport.appendingPathComponent("SimpleClip/Images")
        
        do {
            try fileManager.createDirectory(at: clipboardDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        
        // 计算原始图片数据的 hash（用于去重）
        let imageHash = sha256Hex(imageData)
        
        let filename = "\(UUID().uuidString).png"
        let filePath = clipboardDir.appendingPathComponent(filename)
        
        guard let image = NSImage(data: imageData) else { return nil }
        guard let tiffData = image.tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
        
        do {
            try pngData.write(to: filePath)
            return (filePath.path, imageHash)
        } catch {
            return nil
        }
    }
    
    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
