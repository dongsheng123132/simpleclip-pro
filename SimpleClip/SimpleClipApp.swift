import SwiftUI
import SwiftData
import Sparkle

extension Notification.Name {
    static let switchManagerCategory = Notification.Name("switchManagerCategory")
}

@main
struct SimpleClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var managerWindow: NSWindow?
    var monitor: ClipboardMonitor?
    var summaryService: DailySummaryService?
    var lifeClipExporter: LifeClipExporter?
    var eventMonitor: Any?
    var container: ModelContainer?
    var dailyDigestTimer: Timer?
    var updaterController: SPUStandardUpdaterController!

    /// 固定的数据存储目录（不依赖沙盒容器，签名变化也不影响）
    private static let appSupportURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("SimpleClip")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 一次性迁移：从旧沙盒容器迁移数据
        Self.migrateFromOldContainersIfNeeded()

        // 初始化 SwiftData — 指定固定路径
        do {
            let storeURL = Self.appSupportURL.appendingPathComponent("SimpleClip.store")
            let config = ModelConfiguration(url: storeURL)
            container = try ModelContainer(for: ClipboardItem.self, DailyDigest.self, configurations: config)
        } catch {
            NSLog("❌ 数据库初始化失败: \(error)")
            showDatabaseErrorAlert(error: error)
            return
        }

        // 初始化 Sparkle 自动更新
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            showStatusBarError()
            return
        }

        // 设置按钮
        button.target = self
        
        // 设置图标
        setupStatusBarIcon(button: button)

        // 设置点击行为
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // 设置 Popover
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient
        popover.animates = false  // 禁用动画防止 _NSWindowTransformAnimation 崩溃

        // 创建监听器与日报服务
        setupServices()

        // 设置内容视图
        setupPopoverContent()

        // 延迟执行日报生成，确保 SwiftData 完全初始化
        DispatchQueue.main.async { [weak self] in
            self?.scheduleDailyDigestTimer()
        }
        
        // 监听设置变化
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.dailyDigestTimer?.invalidate()
                self.dailyDigestTimer = nil
                self.scheduleDailyDigestTimer()

                // Toggle LifeClip export based on setting
                let exportEnabled = UserDefaults.standard.bool(forKey: "lifeClipExportEnabled")
                if exportEnabled && self.lifeClipExporter == nil {
                    if let context = self.container?.mainContext {
                        self.lifeClipExporter = LifeClipExporter(modelContext: context)
                        self.lifeClipExporter?.startExporting()
                    }
                } else if !exportEnabled && self.lifeClipExporter != nil {
                    self.lifeClipExporter?.stopExporting()
                    self.lifeClipExporter = nil
                }
            }
        }

        // 全局快捷键
        setupHotKey()

        // 检查辅助功能权限
        checkAccessibilityPermissions()
        
        NSLog("✓ SimpleClip 已启动")
    }
    
    // MARK: - Setup Helpers
    
    private func setupStatusBarIcon(button: NSStatusBarButton) {
        var iconSet = false
        
        // 尝试 SF Symbol
        let symbolNames = ["doc.on.clipboard", "clipboard", "doc", "note.text", "square.on.square"]
        for symbolName in symbolNames {
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "SimpleClip") {
                let iconSize = NSSize(width: 18, height: 18)
                image.size = iconSize
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageOnly
                iconSet = true
                break
            }
        }
        
        // 后备：文本
        if !iconSet {
            button.title = "SC"
            button.imagePosition = .noImage
            button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        }
    }
    
    private func showStatusBarError() {
        let alert = NSAlert()
        alert.messageText = "错误"
        alert.informativeText = "无法创建菜单栏图标"
        alert.alertStyle = .critical
        alert.runModal()
        NSLog("❌ 无法创建状态栏按钮")
    }
    
    private func setupServices() {
        guard let context = container?.mainContext else { return }
        monitor = ClipboardMonitor(modelContext: context)
        monitor?.startMonitoring()
        summaryService = DailySummaryService(modelContext: context)

        // LifeClip Export (optional, controlled by user preference)
        if UserDefaults.standard.bool(forKey: "lifeClipExportEnabled") {
            lifeClipExporter = LifeClipExporter(modelContext: context)
            lifeClipExporter?.startExporting()
        }
    }
    
    private func setupPopoverContent() {
        guard let monitor = monitor, let container = container else { return }
        
        let rootView = PopoverView(
            monitor: monitor,
            onOpenManager: { [weak self] category in
                self?.openManagerWindow(initialCategory: category)
            }
        )
        .modelContainer(container)
        
        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    // MARK: - Window Management
    
    func openManagerWindow(initialCategory: String? = nil) {
        if managerWindow != nil {
            if let category = initialCategory {
                NotificationCenter.default.post(name: .switchManagerCategory, object: category)
            }
            bringManagerWindowToFront()
            return
        }

        guard let container = container else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 900, height: 560)
        window.title = "SimpleClip 剪贴板管理"
        window.center()

        let rootView = ClipboardManagerView(initialCategory: initialCategory)
            .modelContainer(container)

        window.contentViewController = NSHostingController(rootView: rootView)
        managerWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.managerWindow = nil
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.bringManagerWindowToFront()
        }
    }

    private func bringManagerWindowToFront() {
        NSApp.activate(ignoringOtherApps: true)
        managerWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Actions

    @objc func togglePopover(_ sender: Any?) {
        // 右键显示菜单
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        // 左键切换 Popover
        if let button = statusItem?.button {
            if popover.isShown {
                popover.close()  // 使用 close() 替代 performClose 避免动画残留崩溃
            } else {
                // 重建 contentViewController 防止长时间运行后窗口动画对象悬空
                setupPopoverContent()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开管理界面", action: #selector(openManager), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "检查更新…", action: #selector(checkForUpdates), keyEquivalent: "u"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 SimpleClip", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc func openManager() {
        openManagerWindow()
    }

    @objc func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Error Handling

    private func showDatabaseErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "SimpleClip 启动失败"
        alert.informativeText = "无法初始化数据存储：\(error.localizedDescription)\n\n可能的原因：\n• 磁盘空间不足\n• 数据文件损坏\n• 权限问题"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "查看帮助")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com") {
                NSWorkspace.shared.open(url)
            }
        }
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Data Migration

    /// 从旧沙盒容器迁移数据（一次性，迁移完打标记不再执行）
    private static func migrateFromOldContainersIfNeeded() {
        let fm = FileManager.default
        let targetStore = appSupportURL.appendingPathComponent("SimpleClip.store")

        // 已有数据或已迁移过，跳过
        if fm.fileExists(atPath: targetStore.path) { return }

        // 按优先级查找旧数据：容器内 > Application Support 裸文件
        let home = fm.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Containers/com.hequbing.SimpleClip/Data/Library/Application Support/default.store"),
            home.appendingPathComponent("Library/Application Support/default.store"),
        ]

        for oldStore in candidates {
            if fm.fileExists(atPath: oldStore.path) {
                do {
                    try fm.copyItem(at: oldStore, to: targetStore)
                    // 同时复制 WAL/SHM（如果有）
                    for suffix in ["-wal", "-shm"] {
                        let src = URL(fileURLWithPath: oldStore.path + suffix)
                        let dst = URL(fileURLWithPath: targetStore.path + suffix)
                        if fm.fileExists(atPath: src.path) {
                            try? fm.copyItem(at: src, to: dst)
                        }
                    }
                    NSLog("✅ 数据迁移成功: \(oldStore.path) → \(targetStore.path)")
                    return
                } catch {
                    NSLog("⚠️ 数据迁移失败: \(error.localizedDescription)")
                }
            }
        }
        NSLog("ℹ️ 无旧数据需要迁移，首次使用")
    }

    // MARK: - Permissions & HotKey

    func checkAccessibilityPermissions() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            print("需要辅助功能权限以启用自动粘贴功能")
        }
    }

    func setupHotKey() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Command + Shift + V
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 9 {
                self?.togglePopover(nil)
            }
        }
    }

    // MARK: - Lifecycle

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stopMonitoring()
        lifeClipExporter?.stopExporting()
        dailyDigestTimer?.invalidate()
        dailyDigestTimer = nil
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePopover(nil)
        return true
    }

    // MARK: - Daily Digest Timer

    private func scheduleDailyDigestTimer() {
        guard UserDefaults.standard.bool(forKey: "dailyDigestEnabled") != false else { return }
        // 首次延迟生成今日日报（确保 SwiftData 完全就绪）
        summaryService?.tryEnsureTodayDigest()
        let hour = UserDefaults.standard.object(forKey: "dailyDigestHour") as? Int ?? 22
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        components.second = 0
        var next = calendar.date(from: components) ?? Date()
        if next <= Date() {
            next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
        }
        let interval = next.timeIntervalSinceNow
        dailyDigestTimer = Timer.scheduledTimer(withTimeInterval: max(interval, 60), repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.summaryService?.tryEnsureTodayDigest()
                self.rescheduleDailyDigestTimer()
            }
        }
        RunLoop.main.add(dailyDigestTimer!, forMode: .common)
    }

    private func rescheduleDailyDigestTimer() {
        dailyDigestTimer?.invalidate()
        guard UserDefaults.standard.bool(forKey: "dailyDigestEnabled") != false else { return }
        let hour = UserDefaults.standard.object(forKey: "dailyDigestHour") as? Int ?? 22
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        components.second = 0
        let next = calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components) ?? Date()) ?? Date()
        let interval = next.timeIntervalSinceNow
        dailyDigestTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.summaryService?.tryEnsureTodayDigest()
                self.rescheduleDailyDigestTimer()
            }
        }
        RunLoop.main.add(dailyDigestTimer!, forMode: .common)
    }
}
