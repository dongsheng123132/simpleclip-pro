import SwiftUI
import SwiftData

struct PopoverView: View {
    @ObservedObject var monitor: ClipboardMonitor
    var lifeClipExporter: LifeClipExporter?
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var allItems: [ClipboardItem]
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var showClearConfirmation = false
    @State private var showDigest = false
    @State private var selectedItemId: UUID? = nil
    @AppStorage("autoPaste") private var autoPaste = true

    var onOpenManager: ((String?) -> Void)?
    

    var filteredItems: [ClipboardItem] {
        let limitedItems = Array(allItems.prefix(200))
        if searchText.isEmpty {
            return limitedItems.sorted { item1, item2 in
                if item1.isPinned != item2.isPinned { return item1.isPinned }
                return item1.timestamp > item2.timestamp
            }
        }
        return limitedItems.filter {
            $0.decryptedContent.localizedCaseInsensitiveContains(searchText)
        }.sorted { item1, item2 in
            if item1.isPinned != item2.isPinned { return item1.isPinned }
            return item1.timestamp > item2.timestamp
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack(spacing: 12) {
                Text("SimpleClip")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
                
                // 剪贴板管理
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    onOpenManager?(nil)
                }) {
                    Label(NSLocalizedString("管理", comment: ""), systemImage: "square.grid.2x2")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help(NSLocalizedString("打开剪贴板管理", comment: ""))
                
                // 图片库
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    onOpenManager?("images")
                }) {
                    Label(NSLocalizedString("图片库", comment: ""), systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help(NSLocalizedString("打开图片库", comment: ""))

                // 更多菜单
                Menu {
                    Button(action: { showDigest = true }) {
                        Label(NSLocalizedString("工作日报", comment: ""), systemImage: "doc.text.magnifyingglass")
                    }
                    Divider()
                    Button(action: { showSettings = true }) {
                        Label(NSLocalizedString("设置…", comment: ""), systemImage: "gearshape")
                    }
                    Divider()
                    Button(action: { NSApp.terminate(nil) }) {
                        Label(NSLocalizedString("退出 SimpleClip", comment: ""), systemImage: "power")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }
                .menuStyle(.borderlessButton)
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Material.bar)
            
            Divider()
            
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField(NSLocalizedString("搜索历史记录...", comment: ""), text: $searchText)
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
                    Text(searchText.isEmpty ? NSLocalizedString("暂无历史记录", comment: "") : NSLocalizedString("未找到匹配项", comment: ""))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            HistoryItemView(
                                item: item,
                                monitor: monitor,
                                isSelected: selectedItemId == item.id,
                                onSelect: { selectedItemId = item.id },
                                onCopy: { copyItem(item) }
                            )
                            Divider()
                        }
                    }
                }
            }
            
            Divider()
            
            // 底部工具栏
            HStack {
                Text(String(format: NSLocalizedString("%lld 项", comment: ""), filteredItems.count))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: { showClearConfirmation = true }) {
                    Label(NSLocalizedString("清空", comment: ""), systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .alert(NSLocalizedString("确定要清空历史记录吗？", comment: ""), isPresented: $showClearConfirmation) {
                    Button(NSLocalizedString("取消", comment: ""), role: .cancel) { }
                    Button(NSLocalizedString("清空", comment: ""), role: .destructive) {
                        monitor.clearHistory()
                        selectedItemId = nil
                    }
                } message: {
                    Text(NSLocalizedString("固定（Pinned）的项目将不会被删除。", comment: ""))
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // 设置弹窗
            .background(
                Color.clear
                    .popover(isPresented: $showSettings) {
                        SettingsView(monitor: monitor, lifeClipExporter: lifeClipExporter)
                    }
            )
        }
        .frame(minWidth: 400, minHeight: 500)
        .sheet(isPresented: $showDigest) {
            DailyDigestView(
                onGenerate: {
                    let delegate = NSApp.delegate as? AppDelegate
                    delegate?.summaryService?.forceRegenerateTodayDigest()
                },
                onRegenerateToday: {
                    let delegate = NSApp.delegate as? AppDelegate
                    delegate?.summaryService?.forceRegenerateTodayDigest()
                }
            )
        }
    }
    
    private func copyItem(_ item: ClipboardItem) {
        if autoPaste {
            monitor.copyAndPaste(item)
        } else {
            monitor.copyToClipboard(item)
        }
        NSApp.hide(nil)
    }
}
