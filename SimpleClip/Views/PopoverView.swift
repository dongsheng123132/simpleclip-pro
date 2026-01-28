import SwiftUI

struct PopoverView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var showClearConfirmation = false
    
    // 获取 AppDelegate 以调用 toggleDetachMode 和获取窗口实例
    private var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }
    
    // 检查是否处于独立窗口模式
    private var isDetached: Bool {
        appDelegate?.detachedWindow != nil
    }
    
    var filteredItems: [ClipboardItem] {
        let items: [ClipboardItem]
        if searchText.isEmpty {
            items = monitor.items
        } else {
            items = monitor.items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 排序：固定项置顶，然后按时间倒序
        return items.sorted { item1, item2 in
            if item1.isPinned != item2.isPinned {
                return item1.isPinned // 固定项排在前面
            }
            return item1.timestamp > item2.timestamp // 按时间倒序
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("SimpleClip")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 固定/独立窗口按钮
                Button(action: {
                    appDelegate?.toggleDetachMode()
                }) {
                    Image(systemName: isDetached ? "pin.fill" : "pin")
                        .font(.system(size: 14))
                        .foregroundColor(isDetached ? .blue : .primary)
                }
                .buttonStyle(.plain)
                .help(isDetached ? "取消固定 (返回菜单栏模式)" : "固定在桌面顶层")
                .padding(.trailing, 8)
                
                // 更多菜单
                Menu {
                    Button(action: { showSettings = true }) {
                        Label("设置...", systemImage: "gearshape")
                    }
                    Divider()
                    Button(action: { NSApp.terminate(nil) }) {
                        Label("退出 SimpleClip", systemImage: "power")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize() // 防止 Menu 占用过多空间
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    Rectangle().fill(Material.bar)
                    if isDetached {
                        WindowDragger(appDelegate: appDelegate)
                    }
                }
            )
            
            Divider()
            
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("搜索历史记录...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 历史记录列表
            if filteredItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("暂无历史记录")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            HistoryItemView(item: item, monitor: monitor)
                            Divider()
                        }
                    }
                }
            }
            
            Divider()
            
            // 底部工具栏
            HStack {
                // 设置按钮移到了顶部，这里可以放其他信息，或者保留快捷入口
                Text("\(filteredItems.count) 项")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: { showClearConfirmation = true }) {
                    Label("清空", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .alert("确定要清空历史记录吗？", isPresented: $showClearConfirmation) {
                    Button("取消", role: .cancel) { }
                    Button("清空", role: .destructive) {
                        monitor.clearHistory()
                    }
                } message: {
                    Text("固定（Pinned）的项目将不会被删除。")
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // 设置弹窗（隐藏的触发器，通过状态控制）
            // 注意：popover 只能依附于视图，这里我们把它依附在底部工具栏或整个视图上
            // 为了避免布局问题，可以使用 background 挂载
            .background(
                Color.clear
                    .popover(isPresented: $showSettings) {
                        SettingsView(monitor: monitor)
                    }
            )
        }
        .frame(minWidth: 400, minHeight: 500) // 使用 min 尺寸，允许拉伸
    }
}

// 辅助视图：处理窗口拖拽
struct WindowDragger: NSViewRepresentable {
    weak var appDelegate: AppDelegate?
    
    func makeNSView(context: Context) -> DraggableView {
        let view = DraggableView()
        view.appDelegate = appDelegate
        return view
    }
    
    func updateNSView(_ nsView: DraggableView, context: Context) {
        nsView.appDelegate = appDelegate
    }
    
    class DraggableView: NSView {
        weak var appDelegate: AppDelegate?
        
        override var mouseDownCanMoveWindow: Bool { true }
        
        override func mouseDown(with event: NSEvent) {
            // 尝试获取当前窗口
            if let window = self.window {
                window.performDrag(with: event)
            } else if let window = appDelegate?.detachedWindow {
                // 如果视图还没关联到窗口（不太可能），尝试直接操作 detachedWindow
                window.performDrag(with: event)
            }
        }
        
        // 确保视图是透明的但能接收事件
        override func hitTest(_ point: NSPoint) -> NSView? {
            // 只有当点击位置不在子视图（如按钮）上时，才返回自己
            // 但在这里我们是作为 overlay 覆盖在除了按钮以外的区域
            // 所以我们返回自己来捕获点击
            return super.hitTest(point)
        }
    }
}
