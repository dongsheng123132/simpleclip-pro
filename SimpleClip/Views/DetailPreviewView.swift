import SwiftUI

struct DetailPreviewView: View {
    let item: ClipboardItem
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 内容区域
            ScrollView {
                contentView
                    .padding()
            }
        }
        .frame(width: 350, height: 350)
    }
    
    var title: String {
        switch item.type {
        case .text: return "文本预览"
        case .url: return "链接预览"
        case .image: return "图片预览"
        }
    }
    
    @ViewBuilder
    var contentView: some View {
        switch item.type {
        case .text, .url:
            Text(item.content)
                .font(.body)
                .textSelection(.enabled) // 允许选择文本
                .frame(maxWidth: .infinity, alignment: .leading)
                
        case .image:
            if let image = NSImage(contentsOfFile: item.content) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
            } else {
                VStack {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("图片无法加载")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
    }
}
