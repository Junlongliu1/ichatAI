// FileManager.swift
// 文件管理器
import Foundation
import Combine

class DownloadedFileManager: ObservableObject {
    @Published var files: [DownloadedFile] = []             // 下载文件列表
    @Published var selectedCategory: FileCategory = .all    // 当前选中的文件分类
    
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
                    
                    let fileType: FileType
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
