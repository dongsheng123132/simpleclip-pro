import SwiftUI
import SwiftData

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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var managerWindow: NSWindow? // 记忆库管理窗口
    var monitor: ClipboardMonitor?
    var summaryService: DailySummaryService?
    var eventMonitor: Any?
    var container: ModelContainer?
    var dailyDigestTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化 SwiftData - 优雅降级处理
        do {
            container = try ModelContainer(for: ClipboardItem.self, DailyDigest.self)
        } catch {
            NSLog("❌ 数据库初始化失败: \(error)")
            showDatabaseErrorAlert(error: error)
            return
        }

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

        // 创建监听器与日报服务
        setupServices()

        // 设置内容视图
        setupPopoverContent()

        // 设置定时器
        scheduleDailyDigestTimer()
        
        // 监听设置变化
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.dailyDigestTimer?.invalidate()
            self?.dailyDigestTimer = nil
            self?.scheduleDailyDigestTimer()
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
        if UserDefaults.standard.bool(forKey: "dailyDigestEnabled") != false {
            summaryService?.tryEnsureTodayDigest()
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
            queue: nil
        ) { [weak self] _ in
            self?.managerWindow = nil
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
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开管理界面", action: #selector(openManager), keyEquivalent: "m"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 SimpleClip", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc func openManager() {
        openManagerWindow()
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
            self?.summaryService?.tryEnsureTodayDigest()
            self?.rescheduleDailyDigestTimer()
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
            self?.summaryService?.tryEnsureTodayDigest()
            self?.rescheduleDailyDigestTimer()
        }
        RunLoop.main.add(dailyDigestTimer!, forMode: .common)
    }
}
