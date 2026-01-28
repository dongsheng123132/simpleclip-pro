import Foundation
import AppKit
import Combine
import ApplicationServices

class ClipboardMonitor: ObservableObject {
    @Published var items: [ClipboardItem] = []
    
    private var timer: Timer?
    private var lastChangeCount: Int
    
    // 从 UserDefaults 读取最大数量，默认 50
    private var maxItems: Int {
        let saved = UserDefaults.standard.integer(forKey: "maxHistoryItems")
        return saved > 0 ? saved : 50
    }
    
    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        loadHistory()
    }
    
    // 开始监听
    func startMonitoring() {
        // 确保在主线程上运行 Timer
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkClipboard()
            }
        }
    }
    
    // 停止监听
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    // 检查剪贴板变化
    private func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        
        guard currentChangeCount != lastChangeCount else { return }
        
        lastChangeCount = currentChangeCount
        
        let pasteboard = NSPasteboard.general
        
        // 处理文本
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // 检查是否是 URL
            if let url = URL(string: string), url.scheme != nil {
                addItem(ClipboardItem(content: string, type: .url))
            } else {
                addItem(ClipboardItem(content: string, type: .text))
            }
        }
        // 处理图片
        else if let image = pasteboard.data(forType: .tiff) {
            // 保存图片到本地
            if let imagePath = saveImage(image) {
                addItem(ClipboardItem(content: imagePath, type: .image))
            }
        }
    }
    
    // 添加新项目
    private func addItem(_ item: ClipboardItem) {
        // 避免重复
        if let lastItem = items.first, lastItem.content == item.content {
            return
        }
        
        items.insert(item, at: 0)
        
        // 限制数量（保留固定项）
        let pinnedItems = items.filter { $0.isPinned }
        let unpinnedItems = items.filter { !$0.isPinned }
        
        if unpinnedItems.count > maxItems {
            items = pinnedItems + Array(unpinnedItems.prefix(maxItems))
        }
        
        saveHistory()
    }
    
    // 复制到剪贴板
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text, .url:
            pasteboard.setString(item.content, forType: .string)
        case .image:
            if let image = NSImage(contentsOfFile: item.content) {
                pasteboard.writeObjects([image])
            }
        }
        
        // 更新 changeCount 避免重复记录
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    // 复制并自动粘贴到前台应用
    func copyAndPaste(_ item: ClipboardItem) {
        copyToClipboard(item)
        pasteToFrontmostApp()
    }
    
    // 发送 Command+V 到前台应用（需要“辅助功能”权限）
    private func pasteToFrontmostApp() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // 9 = V
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // 删除项目
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    // 切换固定状态
    func togglePin(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isPinned.toggle()
            saveHistory()
        }
    }
    
    // 清空历史（保留固定项）
    func clearHistory() {
        items = items.filter { $0.isPinned }
        saveHistory()
    }
    
    // 保存图片
    private func saveImage(_ imageData: Data) -> String? {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let clipboardDir = appSupport.appendingPathComponent("SimpleClip/Images")
        
        try? fileManager.createDirectory(at: clipboardDir, withIntermediateDirectories: true)
        
        let filename = "\(UUID().uuidString).png"
        let filePath = clipboardDir.appendingPathComponent(filename)
        
        if let image = NSImage(data: imageData),
           let pngData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: pngData),
           let data = bitmap.representation(using: .png, properties: [:]) {
            try? data.write(to: filePath)
            return filePath.path
        }
        
        return nil
    }
    
    // 持久化保存
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "clipboardHistory")
        }
    }
    
    // 加载历史
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "clipboardHistory"),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            items = decoded
        }
    }
}
