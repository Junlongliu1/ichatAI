// FileManager.swift
// 文件管理器
import SwiftUI
import Combine

class DownloadedFileManager: ObservableObject {
    @Published var files: [DownloadedFile] = []                 // 存储所有下载的文件
    @Published var selectedCategory: FileCategory = .all        // 当前选中的分类
    
    //  文件分类枚举
    enum FileCategory: String, CaseIterable, Identifiable {
        case all = "全部"
        case image = "图片"
        case document = "文档"
        case video = "视频"
        case other = "其他"
        
        var id: String { rawValue }
        
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
    
    //接受 JS 传来的 Blob Data URI，写入 App 沙盒
    struct DownloadedFile: Identifiable {
        let id = UUID()
        let fileName: String
        let fileURL: URL
        let fileType: FileType
        let fileSize: Int64
        let createdAt: Date
        
        enum FileType {
            case image
            case pdf
            case video
            case other
            
            var icon: String {
                switch self {
                case .image: return "photo"
                case .pdf: return "doc.richtext"
                case .video: return "video"
                case .other: return "doc"
                }
            }
            
            var color: Color {
                switch self {
                case .image: return .blue
                case .pdf: return .red
                case .video: return .purple
                case .other: return .gray
                }
            }
            
            var category: FileCategory {
                switch self {
                case .image: return .image
                case .pdf: return .document
                case .video: return .video
                case .other: return .other
                }
            }
        }
    }
    
    // 根据当前分类返回过滤后的文件
    var filteredFiles: [DownloadedFile] {
        guard selectedCategory != .all else { return files }
        return files.filter { $0.fileType.category == selectedCategory }
    }
    
    // 获取指定分类的文件数量
    func count(for category: FileCategory) -> Int {
        guard category != .all else { return files.count }
        return files.filter { $0.fileType.category == category }.count
    }
    
    // 初始化时加载文件列表
    init() {
        loadFiles()
    }
    
    //  加载文件列表
    func loadFiles() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            files = fileURLs
                .filter { $0.lastPathComponent.hasPrefix("doubao_") }
                .map { url in
                    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = attributes?[.size] as? Int64 ?? 0
                    let createdAt = attributes?[.creationDate] as? Date ?? Date()
                    
                    let fileType: DownloadedFile.FileType
                    let ext = url.pathExtension.lowercased()
                    if ["png", "jpg", "jpeg", "webp"].contains(ext) {
                        fileType = .image
                    } else if ext == "pdf" {
                        fileType = .pdf
                    } else if ["mp4", "mov", "avi"].contains(ext) {
                        fileType = .video
                    } else {
                        fileType = .other
                    }
                    
                    return DownloadedFile(
                        fileName: url.lastPathComponent,
                        fileURL: url,
                        fileType: fileType,
                        fileSize: fileSize,
                        createdAt: createdAt
                    )
                }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            AppLog("加载文件列表失败: \(error.localizedDescription)")
        }
    }
    
    //  删除指定文件
    func deleteFile(_ file: DownloadedFile) {
        do {
            try FileManager.default.removeItem(at: file.fileURL)
            files.removeAll { $0.id == file.id }
        } catch {
            AppLog("删除文件失败: \(error.localizedDescription)")
        }
    }
    
    //  删除所有文件
    func deleteAllFiles() {
        for file in files {
            deleteFile(file)
        }
    }
}
