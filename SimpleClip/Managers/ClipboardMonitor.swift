import Foundation
import AppKit
import Combine
import ApplicationServices
import SwiftData

class ClipboardMonitor: NSObject, ObservableObject {
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
        DispatchQueue.main.async {
            self.timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkClipboard()
                }
            }
            self.timer?.tolerance = 0.5
            if let timer = self.timer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
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

        // 调试：打印所有可用的类型
        if let types = pasteboard.types {
            NSLog("📋 剪贴板类型: \(types.map { $0.rawValue })")
        }

        // 尝试多种方式读取字符串内容
        var content: String? = nil
        
        // 1. 优先尝试读取普通字符串
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            content = string
            NSLog("📋 从 .string 读取: \(String(string.prefix(100)))")
        }
        // 2. 尝试读取 URL 类型
        else if let urlString = pasteboard.string(forType: .URL), !urlString.isEmpty {
            content = urlString
            NSLog("📋 从 .URL 读取: \(String(urlString.prefix(100)))")
        }
        // 3. 尝试读取 public.url
        else if let types = pasteboard.types {
            for type in types {
                if type.rawValue.contains("url") || type.rawValue.contains("URL") {
                    if let data = pasteboard.data(forType: type),
                       let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii),
                       !string.isEmpty {
                        content = string
                        NSLog("📋 从 \(type.rawValue) 读取: \(String(string.prefix(100)))")
                        break
                    }
                }
            }
        }
        
        // 处理文本/URL
        if let string = content {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                NSLog("⚠️ 内容为空（仅空白字符）")
                return
            }
            
            // 更完善的 URL 检测
            let type: ClipboardType = isValidURL(trimmed) ? .url : .text
            NSLog("📋 判定类型: \(type)")
            
            addItem(ClipboardItem(content: trimmed, type: type))
        }
        // 处理图片
        else if let image = pasteboard.data(forType: .tiff), let imagePath = saveImage(image) {
            NSLog("📋 检测到图片: \(imagePath)")
            addItem(ClipboardItem(content: imagePath, type: .image))
        } else {
            NSLog("⚠️ 未能识别的剪贴板内容")
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
        // 确保在主线程操作 ModelContext
        if !Thread.isMainThread {
            Task { @MainActor in
                addItem(item)
            }
            return
        }
        
        let hashValue: String = item.contentHash
        NSLog("🔍 检查重复 - hash: \(hashValue.prefix(16))..., 内容: \(String(item.content.prefix(50)))")
        
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate<ClipboardItem> { row in row.contentHash == hashValue },
            sortBy: []
        )
        descriptor.fetchLimit = 1
        
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                // 重复内容：更新时间戳，置顶显示
                existing.timestamp = Date()
                try modelContext.save()
                NSLog("🔄 重复内容已更新置顶: \(existing.content.prefix(50))")
                return
            }
            modelContext.insert(item)
            try modelContext.save()
            NSLog("✅ 已保存新项目: \(String(item.content.prefix(50)))")
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
                } else {
                    NSLog("⚠️ 图片已存在但无法加载: \(item.content)")
                }
            } else {
                NSLog("⚠️ 图片文件不存在: \(item.content)")
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
            // 回滚状态
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

    private func saveImage(_ imageData: Data) -> String? {
        let fileManager = FileManager.default
        
        // 获取应用支持目录
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            NSLog("❌ 无法获取 Application Support 目录")
            return nil
        }
        
        let clipboardDir = appSupport.appendingPathComponent("SimpleClip/Images")
        
        // 创建目录并处理错误
        do {
            try fileManager.createDirectory(at: clipboardDir, withIntermediateDirectories: true)
        } catch {
            NSLog("❌ 创建图片目录失败: \(error.localizedDescription)")
            return nil
        }
        
        let filename = "\(UUID().uuidString).png"
        let filePath = clipboardDir.appendingPathComponent(filename)
        
        // 验证图片数据
        guard let image = NSImage(data: imageData) else {
            NSLog("⚠️ 无效的图片数据")
            return nil
        }
        
        guard let tiffData = image.tiffRepresentation else {
            NSLog("⚠️ 无法获取 TIFF 表示")
            return nil
        }
        
        guard let bitmap = NSBitmapImageRep(data: tiffData) else {
            NSLog("⚠️ 无法创建位图表示")
            return nil
        }
        
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            NSLog("⚠️ 无法转换为 PNG 格式")
            return nil
        }
        
        // 写入文件并处理错误
        do {
            try pngData.write(to: filePath)
            NSLog("✅ 图片已保存: \(filePath.path)")
            return filePath.path
        } catch {
            NSLog("❌ 保存图片失败: \(error.localizedDescription)")
            return nil
        }
    }
}
