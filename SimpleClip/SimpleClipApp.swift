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
    var monitor: ClipboardMonitor?
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
            button.action = #selector(togglePopover)
        }
        
        // 设置 Popover
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        
        // 创建监听器
        monitor = ClipboardMonitor()
        monitor?.startMonitoring()
        
        // 设置内容视图
        // 注意：这里需要传入 monitor
        if let monitor = monitor {
            popover.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor))
        }
        
        // 全局快捷键 Command+Shift+V
        setupHotKey()
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // 激活应用以确保输入框获得焦点
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func setupHotKey() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Command + Shift + V
            // keyCode 9 corresponds to 'V' (ANSI_V)
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 9 {
                self?.togglePopover()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stopMonitoring()
    }
}
