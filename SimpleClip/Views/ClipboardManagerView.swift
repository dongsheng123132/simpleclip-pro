import SwiftUI
import SwiftData

// MARK: - 主视图：三栏管理界面（极简版）
struct ClipboardManagerView: View {
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]
    @State private var selectedCategory: String? = "all"
    @State private var searchText = ""
    @State private var selectedItemId: UUID? = nil
    @Environment(\.modelContext) private var modelContext

    var initialCategory: String?
    init(initialCategory: String? = nil) {
        self.initialCategory = initialCategory
    }

    private func dateFilter(_ item: ClipboardItem) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch selectedCategory {
        case "today": return cal.isDateInToday(item.timestamp)
        case "yesterday": return cal.isDateInYesterday(item.timestamp)
        case "thisWeek": return cal.isDate(item.timestamp, equalTo: now, toGranularity: .weekOfYear)
        case "thisMonth": return cal.isDate(item.timestamp, equalTo: now, toGranularity: .month)
        case "earlier":
            let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            return item.timestamp < startOfThisMonth
        default: return true
        }
    }

    var filteredItems: [ClipboardItem] {
        let byCategory: [ClipboardItem]
        switch selectedCategory {
        case "today", "yesterday", "thisWeek", "thisMonth", "earlier":
            byCategory = items.filter { dateFilter($0) }
        case "images":
            byCategory = items.filter { $0.type == .image }
        case "links":
            byCategory = items.filter { $0.type == .url }
        case "text":
            byCategory = items.filter { $0.type == .text }
        case "pinned":
            byCategory = items.filter { $0.isPinned }
        case "frequent":
            byCategory = items.filter { $0.copyCount >= 3 }.sorted { $0.copyCount > $1.copyCount }
        default:
            byCategory = items
        }
        if searchText.isEmpty { return byCategory }
        return byCategory.filter { $0.decryptedContent.localizedStandardContains(searchText) }
    }

    var selectedItem: ClipboardItem? {
        items.first { $0.id == selectedItemId }
    }

    var body: some View {
        NavigationSplitView {
            // 左栏：筛选器
            List(selection: $selectedCategory) {
                Section("按时间") {
                    Label("今天", systemImage: "sun.max").tag("today")
                    Label("昨天", systemImage: "moon").tag("yesterday")
                    Label("本周", systemImage: "calendar").tag("thisWeek")
                    Label("本月", systemImage: "calendar.badge.clock").tag("thisMonth")
                    Label("更早", systemImage: "clock.arrow.circlepath").tag("earlier")
                }
                Section("按类型") {
                    Label("全部", systemImage: "tray.full").tag("all")
                    Label("图片", systemImage: "photo").tag("images")
                    Label("链接", systemImage: "link").tag("links")
                    Label("文本", systemImage: "text.quote").tag("text")
                }
                Section("收藏") {
                    Label("固定", systemImage: "star.fill").tag("pinned")
                    Label("高频复制", systemImage: "flame.fill").tag("frequent")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(NSLocalizedString("SimpleClip", comment: ""))
            .frame(minWidth: 180)

        } content: {
            // 中栏：列表
            Group {
                if selectedCategory == "images" {
                    SimpleImageListView(
                        items: filteredItems,
                        selectedId: $selectedItemId
                    )
                } else {
                    List(filteredItems, id: \.id, selection: $selectedItemId) { item in
                        SimpleListRow(item: item, isSelected: selectedItemId == item.id)
                            .tag(item.id)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 280)
            .searchable(text: $searchText, placement: .toolbar, prompt: NSLocalizedString("搜索...", comment: ""))

        } detail: {
            // 右栏：详情预览
            if let item = selectedItem {
                SimpleDetailView(item: item, onDelete: { deleteItem(item) })
            } else {
                EmptyDetailView()
            }
        }
        .onAppear {
            if let category = initialCategory {
                selectedCategory = category
            }
            selectFirstItem()
        }
        .onChange(of: selectedCategory) { _, _ in
            selectFirstItem()
        }
        .onChange(of: searchText) { _, _ in
            selectFirstItem()
        }
    }

    private func selectFirstItem() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            selectedItemId = filteredItems.first?.id
        }
    }

    private func deleteItem(_ item: ClipboardItem) {
        modelContext.delete(item)
        try? modelContext.save()
        if selectedItemId == item.id {
            selectedItemId = nil
            selectFirstItem()
        }
    }
}

// MARK: - 简化列表行
struct SimpleListRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)

            // 内容预览
            Text(item.preview)
                .lineLimit(2)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)

            // 复制次数
            if item.copyCount > 1 {
                Text("×\(item.copyCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            // 时间
            Text(item.timeAgo)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch item.type {
        case .text: return "text.quote"
        case .image: return "photo"
        case .url: return "link"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .text: return .primary
        case .image: return .purple
        case .url: return .blue
        }
    }
}

// MARK: - 简化图片列表
struct SimpleImageListView: View {
    let items: [ClipboardItem]
    @Binding var selectedId: UUID?

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    SimpleImageCell(item: item, isSelected: selectedId == item.id)
                        .onTapGesture { selectedId = item.id }
                }
            }
            .padding()
        }
    }
}

struct SimpleImageCell: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        ZStack {
            Color.gray.opacity(0.1)

            if let image = loadImage(at: item.content) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
        }
        .frame(height: 100)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        )
    }

    private func loadImage(at path: String) -> NSImage? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSImage(contentsOfFile: path)
    }
}

// MARK: - 详情视图（右侧）
struct SimpleDetailView: View {
    let item: ClipboardItem
    let onDelete: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text(item.timestamp, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if item.copyCount > 1 {
                    Text("×\(item.copyCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    contentView
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }

            Divider()

            // 底部操作栏
            HStack(spacing: 16) {
                // 图片显示"在 Finder 中打开"
                if item.type == .image {
                    Button {
                        showInFinder(path: item.content)
                    } label: {
                        Label(NSLocalizedString("在 Finder 中显示", comment: ""), systemImage: "folder")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                
                Spacer()
                
                // 复制按钮
                Button {
                    copyToPasteboard()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? NSLocalizedString("已复制", comment: "") : NSLocalizedString("复制", comment: ""), systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func showInFinder(path: String) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            NSLog("⚠️ 文件不存在: \(path)")
            return
        }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.type {
        case .image:
            if let image = loadImage(at: item.content) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
            } else {
                Text(NSLocalizedString("[图片无法加载]", comment: ""))
                    .foregroundColor(.secondary)
            }

        case .url:
            if let url = URL(string: item.decryptedContent) {
                Link(item.decryptedContent, destination: url)
                    .font(.body)
                    .foregroundColor(.blue)
                    .textSelection(.enabled)
            } else {
                Text(item.decryptedContent)
                    .font(.body)
                    .textSelection(.enabled)
            }

        case .text:
            Text(item.decryptedContent)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    private func loadImage(at path: String) -> NSImage? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSImage(contentsOfFile: path)
    }

    private func copyToPasteboard() {
        let p = NSPasteboard.general
        p.clearContents()
        switch item.type {
        case .text, .url:
            p.setString(item.decryptedContent, forType: .string)
        case .image:
            if let image = loadImage(at: item.content) {
                p.writeObjects([image])
            }
        }
    }
}

// MARK: - 空状态视图
struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(NSLocalizedString("选择一条记录", comment: ""))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
