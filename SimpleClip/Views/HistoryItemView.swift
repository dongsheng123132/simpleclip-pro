import SwiftUI

struct HistoryItemView: View {
    let item: ClipboardItem
    @ObservedObject var monitor: ClipboardMonitor
    @State private var isHovering = false
    @State private var showPreview = false // 预览状态
    @AppStorage("autoPaste") private var autoPaste = true
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 类型图标 - 点击预览
            ZStack {
                Color.clear
                    .contentShape(Rectangle()) // 扩大点击区域
                    .frame(width: 30, height: 30)
                
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            .onTapGesture {
                showPreview = true
            }
            // 使用 popover 实现预览气泡
            .popover(isPresented: $showPreview, arrowEdge: .leading) {
                DetailPreviewView(item: item)
            }
            
            // 内容区域
            Text(item.preview)
                .lineLimit(2) // 改为2行
                .truncationMode(.tail)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 右侧信息：时间和图标
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.timeAgo)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
            }
            .layoutPriority(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(height: 50) // 固定高度，整齐划一
        .background(isHovering ? Color.blue.opacity(0.1) : Color.clear)
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if autoPaste {
                monitor.copyAndPaste(item)
            } else {
                monitor.copyToClipboard(item)
                // 只有在非自动粘贴模式且不是独立窗口时才隐藏
                // 但这里为了简化，我们让 Monitor 处理粘贴时的焦点
                // 如果是单纯复制，不需要隐藏窗口
            }
            
            // 如果不是独立窗口模式，则隐藏
            // 由于在这里很难直接判断 appDelegate 状态，我们依赖 pasteToFrontmostApp 的行为
            // 但如果仅仅是复制，我们通常希望隐藏 Popover
            if let delegate = NSApp.delegate as? AppDelegate, delegate.detachedWindow == nil {
                NSApp.hide(nil)
            }
        }
        .contextMenu {
            Button(action: { showPreview = true }) {
                Label("预览", systemImage: "doc.text.magnifyingglass")
            }

            Button(action: {
                if autoPaste {
                    monitor.copyAndPaste(item)
                } else {
                    monitor.copyToClipboard(item)
                }
                if let delegate = NSApp.delegate as? AppDelegate, delegate.detachedWindow == nil {
                    NSApp.hide(nil)
                }
            }) {
                Label("复制并粘贴", systemImage: "doc.on.doc")
            }

            Divider()

            Button(action: { monitor.togglePin(item) }) {
                Label(item.isPinned ? "取消固定" : "固定", systemImage: item.isPinned ? "pin.slash" : "pin")
            }

            Button(action: { monitor.deleteItem(item) }) {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private var iconName: String {
        switch item.type {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .image: return "photo"
        }
    }
    
    private var iconColor: Color {
        switch item.type {
        case .text: return .primary.opacity(0.8)
        case .url: return .blue
        case .image: return .purple
        }
    }
}
