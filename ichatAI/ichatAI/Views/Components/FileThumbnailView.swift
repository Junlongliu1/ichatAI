// 文件缩略图视图

import SwiftUI

struct FileThumbnailView: View {
    let file: DownloadedFile        // 下载文件模型
    let width: CGFloat?             // 缩略图宽度
    let height: CGFloat             // 缩略图高度

    @State private var image: UIImage?      // 缩略图图片

    var body: some View {
        Group {
            if file.fileType == .image {
                imageView
            } else {
                fileIconView
            }
        }
        .frame(width: width, height: height)
        .task(id: file.fileURL) {
            await loadImage()
        }
    }

    // 视图构建器，用于根据文件类型显示不同的视图
    @ViewBuilder
    private var imageView: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.secondary.opacity(0.1)
                .overlay(ProgressView().scaleEffect(0.7))
        }
    }

    // 视图构建器，用于显示文件类型图标
    private var fileIconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [file.fileType.color.opacity(0.15), file.fileType.color.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: file.fileType.icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(file.fileType.color)
        }
    }

    // 异步加载图片
    @MainActor
    private func loadImage() async {
        guard file.fileType == .image else { return }
        let url = file.fileURL
        image = await Task.detached(priority: .utility) {
            UIImage(contentsOfFile: url.path)
        }.value
    }
}
