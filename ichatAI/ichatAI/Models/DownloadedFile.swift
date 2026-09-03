// 下载文件模型

import SwiftUI

// 下载文件模型
struct DownloadedFile: Identifiable {
    let id = UUID()             // 唯一标识符
    let fileName: String        // 文件名
    let fileURL: URL            // 文件路径
    let fileType: FileType      // 文件类型
    let fileSize: Int64         // 文件大小（字节）
    let createdAt: Date         // 创建时间
}

// 文件分类枚举
enum FileCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case image = "图片"
    case document = "文档"
    case video = "视频"
    case other = "其他"

    // 生成唯一标识符
    var id: String { rawValue }

    // 获取对应的图标名称
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .image: return "photo.fill"
        case .document: return "doc.fill"
        case .video: return "video.fill"
        case .other: return "folder.fill"
        }
    }
}

// 文件类型枚举
enum FileType {
    case image
    case pdf
    case video
    case other

    // 获取对应的图标名称
    var icon: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .video: return "video"
        case .other: return "doc"
        }
    }

    // 获取对应的颜色
    var color: Color {
        switch self {
        case .image: return .blue
        case .pdf: return .red
        case .video: return .purple
        case .other: return .gray
        }
    }

    // 获取对应的文件分类
    var category: FileCategory {
        switch self {
        case .image: return .image
        case .pdf: return .document
        case .video: return .video
        case .other: return .other
        }
    }

    // 获取对应的标签
    var label: String {
        switch self {
        case .image: return "IMG"
        case .pdf: return "PDF"
        case .video: return "VID"
        case .other: return "FILE"
        }
    }
}
