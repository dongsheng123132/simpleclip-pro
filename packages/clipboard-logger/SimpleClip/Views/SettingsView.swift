import SwiftUI

struct SettingsView: View {
    @AppStorage("autoPaste") private var autoPaste = true
    @AppStorage("dailyDigestEnabled") private var dailyDigestEnabled = true
    @AppStorage("dailyDigestHour") private var dailyDigestHour = 22
    @ObservedObject var monitor: ClipboardMonitor
    @Environment(\.dismiss) private var dismiss

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
        .frame(width: 300, height: 280)
    }

    private func timeLabel(hour: Int) -> String {
        if hour == 0 { return "0:00" }
        return "\(hour):00"
    }
}
