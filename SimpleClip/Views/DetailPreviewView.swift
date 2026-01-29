import SwiftUI

struct DetailPreviewView: View {
    let item: ClipboardItem

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                contentView
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 380, height: 400)
    }

    private var title: String {
        switch item.type {
        case .text: return "文本预览"
        case .url: return "链接预览"
        case .image: return "图片预览"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.type {
        case .text, .url:
            Text(item.content)
                .font(.body)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .image:
            if let image = NSImage(contentsOfFile: item.content) {
                ZoomableImageView(image: image, maxHeight: 320)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("图片无法加载")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
    }
}
