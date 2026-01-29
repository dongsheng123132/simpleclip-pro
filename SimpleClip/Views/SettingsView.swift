import SwiftUI

struct SettingsView: View {
    @AppStorage("autoPaste") private var autoPaste = true
    @AppStorage("dailyDigestEnabled") private var dailyDigestEnabled = true
    @AppStorage("dailyDigestHour") private var dailyDigestHour = 22
    @ObservedObject var monitor: ClipboardMonitor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("设置")
                .font(.headline)

            Form {
                Section(header: Text("通用")) {
                    Toggle("点击后自动粘贴", isOn: $autoPaste)
                        .help("点击历史记录后，自动模拟 Command+V 粘贴")
                }

                Section(header: Text("工作日报")) {
                    Toggle("每日摘要", isOn: $dailyDigestEnabled)
                        .help("每天自动根据剪贴内容生成日报摘要")
                    if dailyDigestEnabled {
                        Picker("生成时间", selection: $dailyDigestHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(timeLabel(hour: h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section {
                    Button("清空所有历史记录") {
                        monitor.clearHistory()
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.1 (AI Features)")
                            .foregroundColor(.secondary)
                    }
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        HStack {
                            Image(systemName: "power")
                            Text("退出程序")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)

            Button("完成") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(width: 300, height: 320)
    }

    private func timeLabel(hour: Int) -> String {
        if hour == 0 { return "0:00" }
        return "\(hour):00"
    }
}
