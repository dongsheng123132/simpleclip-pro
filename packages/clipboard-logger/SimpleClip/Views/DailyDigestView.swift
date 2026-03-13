import SwiftUI
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

struct DailyDigestView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DailyDigest.date, order: .reverse) private var digests: [DailyDigest]
    @State private var selectedId: UUID?
    @State private var isGenerating = false
    @State private var showAIInfo = false
    var onGenerate: (() -> Void)?
    var onRegenerateToday: (() -> Void)?

    private var selectedDigest: DailyDigest? {
        guard let id = selectedId else { return digests.first }
        return digests.first { $0.id == id }
    }

    private var hasTodayDigest: Bool {
        Calendar.current.isDateInToday(Date()) && digests.contains { Calendar.current.isDateInToday($0.date) }
    }

    /// 检测 Apple Intelligence 是否可用
    private var aiStatus: AIAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            // FoundationModels 可导入且 macOS 版本满足
            return .checkingRuntime
        }
        #endif
        return .osNotSupported
    }

    enum AIAvailability {
        case osNotSupported       // macOS < 26
        case checkingRuntime      // macOS 26+ 但需运行时检查
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(NSLocalizedString("工作日报", comment: ""))
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if hasTodayDigest, let onRegenerate = onRegenerateToday {
                    Button(action: {
                        isGenerating = true
                        onRegenerate()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { isGenerating = false }
                    }) {
                        if isGenerating {
                            HStack(spacing: 4) {
                                ProgressView().scaleEffect(0.7)
                                Text(NSLocalizedString("生成中…", comment: ""))
                                    .font(.caption)
                            }
                        } else {
                            Text(NSLocalizedString("重新生成今日", comment: ""))
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGenerating)
                }
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Material.bar)

            Divider()

            // AI 状态提示横幅
            aiStatusBanner

            if digests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("暂无日报", comment: ""))
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("每日剪贴摘要将在晚间自动生成", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if let onGenerate = onGenerate {
                        Button(action: {
                            isGenerating = true
                            onGenerate()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { isGenerating = false }
                        }) {
                            if isGenerating {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.8)
                                    Text(NSLocalizedString("生成中…", comment: ""))
                                        .font(.caption)
                                }
                            } else {
                                Text(NSLocalizedString("立即生成今日摘要", comment: ""))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isGenerating)
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NavigationSplitView {
                    List(digests, selection: $selectedId) { d in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateLabel(d.date))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(String(format: NSLocalizedString("%lld 条", comment: ""), d.itemCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .tag(d.id)
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 140, maxWidth: 200)
                } detail: {
                    if let d = selectedDigest ?? digests.first {
                        ScrollView {
                            Text(d.summary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(minWidth: 220)
                        .background(Color(NSColor.textBackgroundColor))
                    } else {
                        Text(NSLocalizedString("选择一天查看摘要", comment: ""))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minHeight: 320)
            }
        }
        .frame(minWidth: 380, minHeight: 360)
        .onAppear {
            if selectedId == nil, let first = digests.first {
                selectedId = first.id
            }
        }
    }

    // MARK: - AI Status Banner

    @ViewBuilder
    private var aiStatusBanner: some View {
        switch aiStatus {
        case .osNotSupported:
            aiBanner(
                icon: "info.circle.fill",
                color: .orange,
                title: "当前使用关键词提取模式",
                subtitle: "AI 智能摘要需要 macOS 26.0+ 且开启 Apple Intelligence"
            )
        case .checkingRuntime:
            runtimeAIBanner
        }
    }

    /// 是否为中国大陆区域（通过系统 Locale 检测）
    private var isChinaRegion: Bool {
        let regionCode = Locale.current.region?.identifier ?? Locale.current.identifier
        return regionCode == "CN" || regionCode.contains("zh_CN") || regionCode.contains("zh-Hans_CN")
    }

    @ViewBuilder
    private var runtimeAIBanner: some View {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = FoundationModels.SystemLanguageModel.default
            switch model.availability {
            case .available:
                aiBanner(
                    icon: "sparkles",
                    color: .green,
                    title: "Apple Intelligence 已启用",
                    subtitle: "使用本地 AI 生成智能摘要与建议"
                )
            default:
                if isChinaRegion {
                    aiBanner(
                        icon: "exclamationmark.triangle.fill",
                        color: .red,
                        title: "中国大陆设备暂不支持 Apple Intelligence",
                        subtitle: "当前使用关键词提取模式（硬件级限制，非软件可绕过）点击了解详情"
                    )
                    .onTapGesture { showAIInfo = true }
                } else {
                    aiBanner(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        title: "Apple Intelligence 不可用",
                        subtitle: "当前使用关键词提取模式，点击查看如何开启"
                    )
                    .onTapGesture { showAIInfo = true }
                }
            }
        }
        #endif
    }

    private func aiBanner(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if showAIInfo == false && aiStatus == .checkingRuntime {
                Button(action: { showAIInfo = true }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .sheet(isPresented: $showAIInfo) {
            aiInfoSheet
        }
    }

    private var aiInfoSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("关于 AI 摘要功能")
                    .font(.headline)
                Spacer()
                Button(action: { showAIInfo = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("两种模式", systemImage: "cpu")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("1. **AI 智能摘要**（推荐）：使用 Apple Intelligence 本地大模型，生成自然语言总结 + 决策建议。需要 macOS 26.0+ 且 Apple Intelligence 可用。")
                        .font(.caption)
                    Text("2. **关键词提取**（当前）：使用 NaturalLanguage 框架提取关键词和链接，无需 Apple Intelligence。所有 macOS 14+ 均可用。")
                        .font(.caption)
                }
                .padding(4)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Apple Intelligence 可用条件", systemImage: "checkmark.shield")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("• 硬件：Apple M1 芯片或更新")
                        .font(.caption)
                    Text("• 系统：macOS 26.0 (Tahoe) 或更新")
                        .font(.caption)
                    Text("• 区域：**中国大陆购买的设备目前不支持**（硬件级别限制，与系统语言/地区设置无关）")
                        .font(.caption)
                    Text("• 目前支持的区域：美国、英国、加拿大、澳大利亚、新西兰、南非、欧盟等大部分国家和地区")
                        .font(.caption)
                }
                .padding(4)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("中国大陆用户说明", systemImage: "globe.asia.australia")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Apple 对中国大陆销售的设备（型号以 CH/A 结尾）在硬件层面禁用了 Apple Intelligence。更改系统语言、地区或 VPN 均无法绕过此限制。")
                        .font(.caption)
                    Text("社区方案（需自行承担风险）：GitHub 上有 zouxian、enableAppleAI 等开源工具可解除限制，但需要临时关闭 SIP，可能影响系统安全性。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("官方进展：Apple 正与阿里巴巴合作，计划在未来通过系统更新为中国用户提供本地化的 AI 功能。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }

            Text("无论哪种模式，所有处理均 100% 在本地完成，不联网、不上传任何数据。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()
        }
        .padding()
        .frame(minWidth: 420, minHeight: 400)
    }

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return NSLocalizedString("今天", comment: "")
        }
        if cal.isDateInYesterday(date) {
            return NSLocalizedString("昨天", comment: "")
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}
