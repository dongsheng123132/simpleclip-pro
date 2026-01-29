import SwiftUI
import SwiftData

struct DailyDigestView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DailyDigest.date, order: .reverse) private var digests: [DailyDigest]
    @State private var selectedId: UUID?
    @State private var isGenerating = false
    var onGenerate: (() -> Void)?
    var onRegenerateToday: (() -> Void)?

    private var selectedDigest: DailyDigest? {
        guard let id = selectedId else { return digests.first }
        return digests.first { $0.id == id }
    }

    private var hasTodayDigest: Bool {
        Calendar.current.isDateInToday(Date()) && digests.contains { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("工作日报")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if hasTodayDigest, let onRegenerate = onRegenerateToday {
                    Button(action: {
                        isGenerating = true
                        onRegenerate()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isGenerating = false }
                    }) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Text("重新生成今日")
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

            if digests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("暂无日报")
                        .foregroundStyle(.secondary)
                    Text("每日剪贴摘要将在晚间自动生成")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("摘要与建议均为本地处理，无网络、无上传。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("在 macOS 26+ 且开启 Apple Intelligence 时可使用更强本地 AI 摘要与决策建议。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 2)
                    if let onGenerate = onGenerate {
                        Button(action: {
                            isGenerating = true
                            onGenerate()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isGenerating = false }
                        }) {
                            if isGenerating {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.8)
                                    Text("生成中…")
                                        .font(.caption)
                                }
                            } else {
                                Text("立即生成今日摘要")
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
                            Text("\(d.itemCount) 条")
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
                        Text("选择一天查看摘要")
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

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "今天"
        }
        if cal.isDateInYesterday(date) {
            return "昨天"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}
