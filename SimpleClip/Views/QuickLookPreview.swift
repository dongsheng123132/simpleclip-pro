import SwiftUI

// 简化的快速预览 - 使用 Sheet 展示
struct QuickLookPreviewModifier: ViewModifier {
    @Binding var isPresented: Bool
    let item: QuickLookItem?
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if let item = item {
                    QuickLookSheet(item: item, isPresented: $isPresented)
                }
            }
    }
}

extension View {
    func quickLookPreview(_ isPresented: Binding<Bool>, item: QuickLookItem?) -> some View {
        modifier(QuickLookPreviewModifier(isPresented: isPresented, item: item))
    }
}

// 快速预览 Sheet
struct QuickLookSheet: View {
    let item: QuickLookItem
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(item.title)
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 内容区域
            contentView
                .frame(minWidth: 400, minHeight: 300)
        }
        .frame(width: 600, height: 500)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if let url = item.previewItemURL, let image = NSImage(contentsOfFile: url.path) {
            // 图片预览 - 简单显示
            ScrollView {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 560)
                    .padding()
            }
        } else if let text = item.text {
            // 文本预览
            ScrollView {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        } else {
            VStack {
                Image(systemName: "doc")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("无法预览")
                    .foregroundColor(.secondary)
            }
        }
    }
}
