import SwiftUI
import SwiftData

struct ClipboardManagerView: View {
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]
    @State private var selectedCategory: String? = "all"
    @State private var searchText = ""
    @State private var selectedItemIds: Set<UUID> = []
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
        default:
            byCategory = items
        }
        if searchText.isEmpty { return byCategory }
        return byCategory.filter { $0.content.localizedStandardContains(searchText) }
    }

    var selectedItems: [ClipboardItem] {
        items.filter { selectedItemIds.contains($0.id) }
    }

    var body: some View {
        NavigationSplitView {
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
                    Label("图片", systemImage: "photo.on.rectangle").tag("images")
                    Label("链接", systemImage: "link").tag("links")
                    Label("文本", systemImage: "text.quote").tag("text")
                }
                Section("收藏") {
                    Label("固定", systemImage: "star.fill").tag("pinned")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("剪贴板")
            .frame(minWidth: 200)

        } content: {
            Group {
                if selectedCategory == "images" {
                    ImageGalleryView(items: filteredItems, selectedId: Binding(
                        get: { selectedItemIds.first },
                        set: { if let id = $0 { selectedItemIds = [id] } else { selectedItemIds = [] } }
                    ))
                } else {
                    List(filteredItems, selection: $selectedItemIds) { item in
                        ManagerListItemView(item: item)
                            .tag(item.id)
                    }
                    .listStyle(.inset)
                    .searchable(text: $searchText, placement: .toolbar, prompt: "搜索...")
                }
            }
            .frame(minWidth: 320)

        } detail: {
            ManagerDetailView(
                selectedItems: selectedItems,
                allItems: items,
                onDelete: deleteSelected
            )
            .frame(minWidth: 420)
        }
        .onAppear {
            if let category = initialCategory {
                selectedCategory = category
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchManagerCategory)) { notification in
            if let category = notification.object as? String {
                selectedCategory = category
            }
        }
    }

    private func deleteSelected() {
        for item in selectedItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
        selectedItemIds.removeAll()
    }
}

// 列表项视图
struct ManagerListItemView: View {
    let item: ClipboardItem
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(alignment: .top) {
            // 左侧图标或缩略图
            Group {
                if item.type == .image, let image = ManagerListItemView.downsampledImage(at: item.content, maxPixel: 200) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipped()
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .frame(width: 50, height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        
                        switch item.type {
                        case .text: Image(systemName: "text.quote").font(.title2)
                        case .image: Image(systemName: "photo").font(.title2)
                        case .url: Image(systemName: "link").font(.title2)
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }

            // 中间文字内容
            VStack(alignment: .leading, spacing: 6) {
                Text(item.preview)
                    .lineLimit(3) // 增加到3行
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text(item.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if item.type == .url {
                        Text("• 链接")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 4)
            
            Spacer()
            
            // 右侧固定图标
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button("复制到剪贴板") {
                copyItemToPasteboard(item)
            }
            Button(item.isPinned ? "取消固定" : "固定") {
                item.isPinned.toggle()
                try? modelContext.save()
            }
            Divider()
            Button(role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func copyItemToPasteboard(_ item: ClipboardItem) {
        let p = NSPasteboard.general
        p.clearContents()
        switch item.type {
        case .text, .url:
            p.setString(item.content, forType: .string)
        case .image:
            if let image = NSImage(contentsOfFile: item.content) {
                p.writeObjects([image])
            }
        }
    }
}

extension ManagerListItemView {
    static private var cache = NSCache<NSString, NSImage>()
    static func downsampledImage(at path: String, maxPixel: CGFloat) -> NSImage? {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel),
            kCGImageSourceShouldCache: false
        ]
        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let thumb = NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
        cache.setObject(thumb, forKey: path as NSString)
        return thumb
    }
}

// 图片画廊视图：按日期分组（今天、昨天、本周、更早），类似相册
struct ImageGalleryView: View {
    let items: [ClipboardItem]
    @Binding var selectedId: UUID?

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)
    ]

    private enum DateSection: String, CaseIterable {
        case today = "今天"
        case yesterday = "昨天"
        case thisWeek = "本周"
        case earlier = "更早"
    }

    private func section(for date: Date) -> DateSection {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return .today }
        if cal.isDateInYesterday(date) { return .yesterday }
        if cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) { return .thisWeek }
        return .earlier
    }

    private var grouped: [(DateSection, [ClipboardItem])] {
        let order: [DateSection] = [.today, .yesterday, .thisWeek, .earlier]
        let groupedDict = Dictionary(grouping: items) { section(for: $0.timestamp) }
        return order.compactMap { key in
            guard let list = groupedDict[key], !list.isEmpty else { return nil }
            return (key, list)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(grouped, id: \.0.rawValue) { sectionKey, sectionItems in
                    Section {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(sectionItems) { item in
                                galleryCell(item: item)
                            }
                        }
                    } header: {
                        Text(sectionKey.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
            }
            .padding()
        }
    }

    private func galleryCell(item: ClipboardItem) -> some View {
        VStack(spacing: 6) {
            if let image = NSImage(contentsOfFile: item.content) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 110)
                    .clipped()
                    .cornerRadius(8)
                    .shadow(radius: 1)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 110)
                    .overlay(Image(systemName: "photo.fill").foregroundColor(.gray))
                    .cornerRadius(8)
            }
            Text(item.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(selectedId == item.id ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .onTapGesture { selectedId = item.id }
        .contextMenu {
            Button("查看详情") { selectedId = item.id }
            Button("复制到剪贴板") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                if let image = NSImage(contentsOfFile: item.content) {
                    pasteboard.writeObjects([image])
                }
            }
        }
    }
}

// 右侧详情：放大预览 + 复制/删除，无 AI
struct ManagerDetailView: View {
    let selectedItems: [ClipboardItem]
    let allItems: [ClipboardItem]
    var onDelete: (() -> Void)?

    var body: some View {
        Group {
            if selectedItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("选择一条记录")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("可放大预览、点击复制到剪贴板")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("已选 \(selectedItems.count) 条")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let onDelete = onDelete {
                                Button(role: .destructive) {
                                    onDelete()
                                } label: {
                                    Label("删除选中", systemImage: "trash")
                                }
                            }
                        }
                        Divider()
                        ForEach(selectedItems.sorted(by: { $0.timestamp > $1.timestamp })) { item in
                            ItemDetailCard(item: item)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// 单条内容卡片：放大预览 + 点击复制；图片可放大、文本/链接完整展示
struct ItemDetailCard: View {
    let item: ClipboardItem
    @State private var copied = false
    @State private var showImageZoom = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(item.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                Spacer()
                Button {
                    copyItemToPasteboard(item)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark.circle.fill" : "doc.on.clipboard")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            Divider()
            // 内容区：保证最小高度，避免“看不到”
            contentArea
                .frame(minHeight: 100)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .sheet(isPresented: $showImageZoom) {
            if item.type == .image, let image = NSImage(contentsOfFile: item.content) {
                ImageZoomSheet(image: image, onDismiss: { showImageZoom = false })
            }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        switch item.type {
        case .image:
            if let image = NSImage(contentsOfFile: item.content) {
                VStack(alignment: .leading, spacing: 8) {
                    ZoomableImageView(image: image, maxHeight: 420)
                        .cornerRadius(8)
                    Button {
                        showImageZoom = true
                    } label: {
                        Label("放大查看", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Text("[图片无法加载]")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        case .url:
            VStack(alignment: .leading) {
                Link(destination: URL(string: item.content) ?? URL(string: "https://")!) {
                    Text(item.content)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.blue)
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .text:
            Text(item.content)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func copyItemToPasteboard(_ item: ClipboardItem) {
        let p = NSPasteboard.general
        p.clearContents()
        switch item.type {
        case .text, .url:
            p.setString(item.content, forType: .string)
        case .image:
            if let image = NSImage(contentsOfFile: item.content) {
                p.writeObjects([image])
            }
        }
    }
}

// 支持双指捏合缩放 + 拖拽平移的图片视图（原生触控板/触屏手势）
struct ZoomableImageView: View {
    let image: NSImage
    var maxHeight: CGFloat = 420
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: maxHeight)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { scale = lastScale * $0 }
                    .onEnded { value in
                        lastScale = scale
                        if scale <= 1 {
                            scale = 1
                            lastScale = 1
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1 {
                            offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                        }
                    }
                    .onEnded { _ in lastOffset = offset }
            )
            .onTapGesture(count: 2) {
                scale = 1
                lastScale = 1
                offset = .zero
                lastOffset = .zero
            }
    }
}

// 图片放大弹窗：大图 + 双指缩放/拖拽 + Esc 关闭
struct ImageZoomSheet: View {
    let image: NSImage
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("双指捏合缩放 · 双击还原")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("关闭") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                    .padding()
            }
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZoomableImageView(image: image, maxHeight: 600)
                    .frame(minWidth: 400, minHeight: 300)
            }
            .frame(minWidth: 420, minHeight: 360)
        }
        .frame(width: 560, height: 520)
    }
}

// 脱敏：将包含敏感词的行替换为 [已省略]
enum SensitiveMaskHelper {
    static let defaultKeywords = ["密码", "password", "密钥", "key", "token", "api_key", "secret", "私钥", "Secret", "Token", "API_KEY"]

    static func mask(text: String, keywords: [String]) -> String {
        let lines = text.components(separatedBy: .newlines)
        return lines.map { line in
            let lower = line.lowercased()
            if keywords.contains(where: { lower.contains($0.lowercased()) }) {
                return "[已省略]"
            }
            return line
        }.joined(separator: "\n")
    }
}

// 详情视图（单条全量，用于兼容）
struct ItemDetailView: View {
    let item: ClipboardItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.timestamp, style: .date)
                            .font(.headline)
                        Text(item.timestamp, style: .time)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if item.isPinned {
                        Label("已固定", systemImage: "pin.fill")
                            .foregroundColor(.orange)
                    }
                }
                .padding(.bottom)
                Divider()
                switch item.type {
                case .image:
                    if let image = NSImage(contentsOfFile: item.content) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                    } else {
                        Text("图片无法加载")
                            .foregroundColor(.red)
                    }
                case .url:
                    Link(destination: URL(string: item.content) ?? URL(string: "https://")!) {
                        HStack {
                            Image(systemName: "safari")
                            Text(item.content)
                        }
                        .font(.title3)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                case .text:
                    Text(item.content)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                Spacer()
            }
            .padding()
        }
    }
}

// AI 洞察视图
struct AIInsightView: View {
    let items: [ClipboardItem]
    @Environment(\.dismiss) private var dismiss
    @State private var insightCards: [InsightCardModel] = []
    @State private var isLoading = true
    
    struct InsightCardModel: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        let icon: String
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("AI 记忆洞察")
                    .font(.title2)
                    .bold()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .padding(.leading, 8)
                }
                
                Spacer()
                Button("关闭") { dismiss() }
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        Text("正在分析您的记忆库...")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 50)
                    } else if insightCards.isEmpty {
                        Text("暂无足够的文本数据进行分析")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 50)
                    } else {
                        ForEach(insightCards) { card in
                            InsightCard(title: card.title, content: card.content)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            generateInsights()
        }
    }
    
    private func generateInsights() {
        // 先在主线程提取必要的数据 (String 和 Int 是 Sendable 的)
        let texts = items.filter { $0.type == .text || $0.type == .url }.map(\.content)
        let imageCount = items.filter { $0.type == .image }.count
        let totalCount = items.count
        
        // 在后台进行分析
        Task.detached(priority: .userInitiated) {
            // 模拟或调用简单的本地分析逻辑
            // 真实场景下，这里可以调用 DailySummaryService 的逻辑，或者更高级的 LLM API
            
            // 1. 基础统计
            let summaryCard = InsightCardModel(
                title: "📊 数据概览",
                content: "您当前视图共有 \(totalCount) 条记录。包含 \(imageCount) 张图片，\(texts.count) 段文本。",
                icon: "chart.bar"
            )
            
            // 2. 关键词提取 (使用 NSLinguisticTagger)
            let keywords = Self.extractKeywords(from: texts)
            let keywordCard = InsightCardModel(
                title: "💡 核心关注点",
                content: keywords.isEmpty ? "暂无显著关键词" : "您最近关注的内容主要集中在：\(keywords.joined(separator: "、"))",
                icon: "lightbulb"
            )
            
            // 3. 链接分析
            let domains = Self.extractDomains(from: texts)
            let linkCard = InsightCardModel(
                title: "🌐 知识来源",
                content: domains.isEmpty ? "暂无外部链接" : "您的信息主要来源于：\(domains.joined(separator: ", "))",
                icon: "link"
            )
            
            await MainActor.run {
                self.insightCards = [summaryCard, keywordCard, linkCard]
                self.isLoading = false
            }
        }
    }
    
    // 简单的关键词提取辅助函数
    nonisolated private static func extractKeywords(from texts: [String]) -> [String] {
        var wordCounts: [String: Int] = [:]
        let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
        
        for text in texts.prefix(50) { // 仅分析前50条以保证性能
            tagger.string = text
            let range = NSRange(location: 0, length: text.utf16.count)
            tagger.enumerateTags(in: range, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, tokenRange, _, _ in
                if tag == .noun {
                    let word = (text as NSString).substring(with: tokenRange)
                    if word.count > 1 {
                        wordCounts[word, default: 0] += 1
                    }
                }
            }
        }
        
        return wordCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }
    
    // 简单的域名提取
    nonisolated private static func extractDomains(from texts: [String]) -> [String] {
        var domains: Set<String> = []
        for text in texts {
            if let url = URL(string: text), let host = url.host {
                domains.insert(host)
            }
        }
        return Array(domains.prefix(5))
    }
}

struct InsightCard: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
