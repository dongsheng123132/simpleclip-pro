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
    var detachedWindow: NSWindow?
    var managerWindow: NSWindow? // 记忆库管理窗口
    var monitor: ClipboardMonitor?
    var summaryService: DailySummaryService?
    var eventMonitor: Any?
    var container: ModelContainer?
    var dailyDigestTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化 SwiftData
        do {
            container = try ModelContainer(for: ClipboardItem.self, DailyDigest.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp]) // 支持右键点击
        }

        // 设置 Popover
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient

        // 创建监听器与日报服务
        if let context = container?.mainContext {
            monitor = ClipboardMonitor(modelContext: context)
            monitor?.startMonitoring()
            summaryService = DailySummaryService(modelContext: context)
            if UserDefaults.standard.bool(forKey: "dailyDigestEnabled") != false {
                summaryService?.tryEnsureTodayDigest()
            }
        }

        // 设置内容视图（传入闭包，确保菜单点击能打开管理窗口）
        if let monitor = monitor, let container = container {
            let rootView = PopoverView(
                monitor: monitor,
                onOpenManager: { [weak self] category in
                    self?.openManagerWindow(initialCategory: category)
                },
                onToggleDetach: { [weak self] in
                    self?.toggleDetachMode()
                }
            )
            .modelContainer(container)
            popover.contentViewController = NSHostingController(rootView: rootView)
        }

        scheduleDailyDigestTimer()
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.dailyDigestTimer?.invalidate()
            self?.dailyDigestTimer = nil
            self?.scheduleDailyDigestTimer()
        }

        // 全局快捷键 Command+Shift+V
        setupHotKey()

        // 检查辅助功能权限（用于自动粘贴）
        checkAccessibilityPermissions()
    }
    
    /// 打开剪贴板管理窗口，可选直接进入某分类（如 "images" 截图库）
    func openManagerWindow(initialCategory: String? = nil) {
        if let window = managerWindow {
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
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] _ in
            self?.managerWindow = nil
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // 菜单关闭后再置前一次，避免被 popover/菜单抢焦点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.bringManagerWindowToFront()
        }
    }

    private func bringManagerWindowToFront() {
        NSApp.activate(ignoringOtherApps: true)
        managerWindow?.makeKeyAndOrderFront(nil)
    }
    
    func checkAccessibilityPermissions() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            print("需要辅助功能权限以启用自动粘贴功能")
        }
    }
    
    @objc func togglePopover(_ sender: Any?) {
        // 检查是否是右键点击
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            // 右键点击逻辑（可选，目前保持默认行为或添加特定菜单）
            // 这里我们保持统一行为
        }
        
        if let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // 如果独立窗口存在且可见，则聚焦独立窗口
                if let window = detachedWindow, window.isVisible {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    func toggleDetachMode() {
        if let window = detachedWindow, window.isVisible {
            // 关闭独立窗口
            window.close()
            detachedWindow = nil
        } else {
            // 关闭 Popover
            popover.performClose(nil)
            
            // 创建独立窗口
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.borderless, .resizable], // 无边框模式，更像悬浮窗
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear // 透明背景，由 View 负责背景
            window.hasShadow = true
            window.level = .floating // 置顶
            window.isMovableByWindowBackground = true // 允许拖拽背景移动
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // 允许在所有桌面显示
            window.hidesOnDeactivate = false // 失去焦点时不隐藏
            window.center()
            
            // 设置内容（同样传入闭包）
            if let monitor = monitor, let container = container {
                let rootView = PopoverView(
                    monitor: monitor,
                    onOpenManager: { [weak self] category in
                        self?.openManagerWindow(initialCategory: category)
                    },
                    onToggleDetach: { [weak self] in
                        self?.toggleDetachMode()
                    }
                )
                .modelContainer(container)
                window.contentViewController = NSHostingController(rootView: rootView)
            }
            
            window.makeKeyAndOrderFront(nil)
            detachedWindow = window
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func setupHotKey() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Command + Shift + V
            // keyCode 9 corresponds to 'V' (ANSI_V)
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 9 {
                self?.togglePopover(nil)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stopMonitoring()
        dailyDigestTimer?.invalidate()
        dailyDigestTimer = nil
    }

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
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window = detachedWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
        } else {
            togglePopover(nil)
        }
        return true
    }
}
