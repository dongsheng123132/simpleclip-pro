import SwiftUI

struct HistoryItemView: View {
    let item: ClipboardItem
    @ObservedObject var monitor: ClipboardMonitor
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    
    @State private var isHovering = false
    @State private var showPreview = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 类型图标
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: 30, height: 30)
                
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            
            // 内容区域
            Text(item.preview)
                .lineLimit(2)
                .truncationMode(.tail)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 右侧信息
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
        .frame(height: 50)
        .background(backgroundColor)
        .contentShape(Rectangle())
        .popover(isPresented: $showPreview, arrowEdge: .leading) {
            DetailPreviewView(item: item)
                .frame(width: 380, height: 400)
        }
        .onTapGesture {
            onSelect()
            showPreview = true
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button(action: { showPreview = true }) {
                Label(NSLocalizedString("预览", comment: ""), systemImage: "doc.text.magnifyingglass")
            }
            Button(action: onCopy) {
                Label(NSLocalizedString("复制", comment: ""), systemImage: "doc.on.doc")
            }
            Divider()
            Button(action: { monitor.togglePin(item) }) {
                Label(item.isPinned ? NSLocalizedString("取消固定", comment: "") : NSLocalizedString("固定", comment: ""), 
                      systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive, action: { monitor.deleteItem(item) }) {
                Label(NSLocalizedString("删除", comment: ""), systemImage: "trash")
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovering {
            return Color.blue.opacity(0.1)
        } else {
            return Color.clear
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
