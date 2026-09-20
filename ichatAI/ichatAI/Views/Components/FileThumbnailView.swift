// FileThumbnailView.swift
import SwiftUI
import ImageIO
import UIKit

struct FileThumbnailView: View {
    let file: DownloadedFile
    let width: CGFloat?
    let height: CGFloat

    @Environment(\.displayScale) private var displayScale
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
            await loadThumbnail()
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
    private func loadThumbnail() async {
        guard file.fileType == .image else { return }
        let url = file.fileURL

        if let cached = ThumbnailCache.shared.image(for: url) {
            image = cached
            return
        }

        let maxPixel = max(width ?? 108, height) * displayScale
        let img = await Task.detached(priority: .utility) {
            ThumbnailCache.downsample(url: url, maxPixelSize: maxPixel)
        }.value

        guard !Task.isCancelled else { return }
        if let img { ThumbnailCache.shared.set(img, for: url) }
        image = img
    }
}

// MARK: - 缩略图缓存 + 降采样
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() { cache.countLimit = 200 }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ img: UIImage, for url: URL) {
        cache.setObject(img, forKey: url as NSURL)
    }

    /// 用 ImageIO 生成降采样缩略图
    nonisolated static func downsample(url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOpts as CFDictionary) else {
            return nil
        }

        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}
