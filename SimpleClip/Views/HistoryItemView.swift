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
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .lineLimit(1) // 保持单行
                    .truncationMode(.tail) // 尾部截断
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                
                Text(item.timeAgo)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 仅显示固定状态图标，删除等操作移至右键
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            }
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
            }
            NSApp.hide(nil)
        }
        .contextMenu {
            Button(action: {
                if autoPaste {
                    monitor.copyAndPaste(item)
                } else {
                    monitor.copyToClipboard(item)
                }
                NSApp.hide(nil)
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
