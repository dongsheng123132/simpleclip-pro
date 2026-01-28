import SwiftUI

struct SettingsView: View {
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 50
    @AppStorage("autoPaste") private var autoPaste = true
    @ObservedObject var monitor: ClipboardMonitor
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("设置")
                .font(.headline)
            
            Form {
                Section(header: Text("通用")) {
                    Picker("最大保存数量", selection: $maxHistoryItems) {
                        Text("20 条").tag(20)
                        Text("50 条").tag(50)
                        Text("100 条").tag(100)
                        Text("200 条").tag(200)
                    }
                    .pickerStyle(.menu)
                    
                    Toggle("点击后自动粘贴", isOn: $autoPaste)
                        .help("点击历史记录后，自动模拟 Command+V 粘贴")
                }
                
                Section {
                    Button("清空所有历史记录") {
                        monitor.clearHistory()
                    }
                    .foregroundColor(.red)
                    
                    Button("退出 SimpleClip") {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
            .formStyle(.grouped)
            
            Button("完成") {
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(width: 300, height: 350)
    }
}
