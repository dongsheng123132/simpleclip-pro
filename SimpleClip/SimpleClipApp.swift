import SwiftUI

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
    var monitor: ClipboardMonitor?
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp]) // 支持右键点击
        }
        
        // 设置 Popover
        popover.contentSize = NSSize(width: 400, height: 600) // 增加高度以容纳新头部
        popover.behavior = .transient
        
        // 创建监听器
        monitor = ClipboardMonitor()
        monitor?.startMonitoring()
        
        // 设置内容视图
        if let monitor = monitor {
            popover.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor))
        }
        
        // 全局快捷键 Command+Shift+V
        setupHotKey()
        
        // 检查辅助功能权限（用于自动粘贴）
        checkAccessibilityPermissions()
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
            
            // 设置内容
            if let monitor = monitor {
                // 传入 isDetached = true (需要修改 PopoverView 接口)
                // 这里我们暂时直接复用 View，稍后在 PopoverView 中通过 Environment 或参数判断
                window.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor))
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
