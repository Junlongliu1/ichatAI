// 文件缩略图视图 —— iOS 26 液态玻璃
import SwiftUI

struct FileThumbnailView: View {
    let file: DownloadedFile
    let width: CGFloat?
    let height: CGFloat

    @State private var image: UIImage?

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

    private var fileIconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            file.fileType.color.opacity(0.18),
                            file.fileType.color.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(file.fileType.color.opacity(0.15), lineWidth: 0.5)
                )

            Image(systemName: file.fileType.icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(file.fileType.color)
        }
    }

    @MainActor
    private func loadImage() async {
        guard file.fileType == .image else { return }
        let url = file.fileURL
        image = await Task.detached(priority: .utility) {
            UIImage(contentsOfFile: url.path)
        }.value
    }
}
