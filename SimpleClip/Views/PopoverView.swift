import SwiftUI

struct PopoverView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var showClearConfirmation = false
    
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
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSettings) {
                    SettingsView(monitor: monitor)
                }
                
                Spacer()
                
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
        }
        .frame(width: 400, height: 500)
    }
}
