import SwiftUI

struct SettingsView: View {
    @AppStorage("autoPaste") private var autoPaste = true
    @AppStorage("dailyDigestEnabled") private var dailyDigestEnabled = true
    @AppStorage("dailyDigestHour") private var dailyDigestHour = 22
    @AppStorage(LifeClipExporter.enabledKey) private var lifeClipExportEnabled = false
    @AppStorage("sensitiveAutoCleanup") private var sensitiveAutoCleanup = true
    @AppStorage("exportSkipSensitive") private var exportSkipSensitive = false
    @ObservedObject var monitor: ClipboardMonitor
    var lifeClipExporter: LifeClipExporter?
    @Environment(\.dismiss) private var dismiss
    @State private var cleanedCount: Int?

    var body: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("设置", comment: ""))
                .font(.headline)

            Form {
                Section(header: Text(NSLocalizedString("通用", comment: ""))) {
                    Toggle(NSLocalizedString("双击后自动粘贴", comment: ""), isOn: $autoPaste)
                        .help(NSLocalizedString("双击历史记录后，自动模拟 Command+V 粘贴", comment: ""))
                }

                Section(header: Text(NSLocalizedString("工作日报", comment: ""))) {
                    Toggle(NSLocalizedString("每日摘要", comment: ""), isOn: $dailyDigestEnabled)
                        .help(NSLocalizedString("每天自动根据剪贴内容生成日报摘要", comment: ""))
                    if dailyDigestEnabled {
                        Picker(NSLocalizedString("生成时间", comment: ""), selection: $dailyDigestHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(timeLabel(hour: h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section(header: Text("LifeClip")) {
                    Toggle(NSLocalizedString("导出到 LifeClip", comment: ""), isOn: $lifeClipExportEnabled)
                        .help(NSLocalizedString("定时将剪贴板事件导出为 JSONL，供 LifeClip 分析", comment: ""))
                        .onChange(of: lifeClipExportEnabled) { _, newValue in
                            if newValue {
                                lifeClipExporter?.start()
                            } else {
                                lifeClipExporter?.stop()
                            }
                        }
                    if lifeClipExportEnabled {
                        if let lastDate = lifeClipExporter?.lastExportDate {
                            HStack {
                                Text(NSLocalizedString("上次导出", comment: ""))
                                Spacer()
                                Text(lastDate, style: .relative)
                                    .foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            Text(NSLocalizedString("已导出条数", comment: ""))
                            Spacer()
                            Text("\(lifeClipExporter?.exportedCount ?? 0)")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("隐私", comment: ""))) {
                    Toggle(NSLocalizedString("敏感信息自动清理", comment: ""), isOn: $sensitiveAutoCleanup)
                        .help(NSLocalizedString("自动删除 24 小时前的敏感剪贴（已固定的除外）", comment: ""))
                    Toggle(NSLocalizedString("导出时跳过敏感项", comment: ""), isOn: $exportSkipSensitive)
                        .help(NSLocalizedString("LifeClip 导出时完全跳过含敏感信息的条目", comment: ""))
                    Button(action: {
                        cleanedCount = monitor.cleanSensitiveItemsNow()
                    }) {
                        Text(NSLocalizedString("立即清理敏感信息", comment: ""))
                    }
                    if let count = cleanedCount {
                        Text("已清理 \(count) 条敏感记录")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Section {
                    Button(NSLocalizedString("清空所有历史记录", comment: "")) {
                        monitor.clearHistory()
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text(NSLocalizedString("关于", comment: ""))) {
                    HStack {
                        Text(NSLocalizedString("版本", comment: ""))
                        Spacer()
                        Text("1.1 (AI Features)")
                            .foregroundColor(.secondary)
                    }
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        HStack {
                            Image(systemName: "power")
                            Text(NSLocalizedString("退出程序", comment: ""))
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)

            Button(NSLocalizedString("完成", comment: "")) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(width: 300, height: 520)
    }

    private func timeLabel(hour: Int) -> String {
        if hour == 0 { return "0:00" }
        return "\(hour):00"
    }
}
