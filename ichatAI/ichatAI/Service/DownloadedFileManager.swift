// DownloadedFileManager.swift
import Foundation
import Observation

enum FileSortOption: String, CaseIterable, Identifiable {
    case dateDescending = "最新优先"
    case dateAscending  = "最早优先"
    case sizeDescending = "最大优先"
    case sizeAscending  = "最小优先"
    case nameAscending  = "名称 A-Z"
    var id: String { rawValue }
}

@MainActor
@Observable
final class DownloadedFileManager {
    private(set) var files: [DownloadedFile] = []

    var selectedCategory: FileCategory = .all
    var searchText: String = ""
    var sortOption: FileSortOption = .dateDescending

    private let knownPrefixes = ["ai_", "doubao_"]

    @ObservationIgnored
    private var observer: NSObjectProtocol?

    init() {
        loadFiles()
        observer = NotificationCenter.default.addObserver(
            forName: .downloadedFileAdded,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadFiles()
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: - 派生
    var filteredFiles: [DownloadedFile] {
        var result = files

        if selectedCategory != .all {
            result = result.filter { $0.fileType.category == selectedCategory }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { $0.fileName.lowercased().contains(q) }
        }

        switch sortOption {
        case .dateDescending: result.sort { $0.createdAt > $1.createdAt }
        case .dateAscending:  result.sort { $0.createdAt < $1.createdAt }
        case .sizeDescending: result.sort { $0.fileSize > $1.fileSize }
        case .sizeAscending:  result.sort { $0.fileSize < $1.fileSize }
        case .nameAscending:  result.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        }

        return result
    }

    func count(for category: FileCategory) -> Int {
        guard category != .all else { return files.count }
        return files.filter { $0.fileType.category == category }.count
    }

    // MARK: - 加载
    func loadFiles() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )

            files = fileURLs
                .filter { url in
                    knownPrefixes.contains { url.lastPathComponent.hasPrefix($0) }
                }
                .map { url in
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = attrs?[.size] as? Int64 ?? 0
                    let createdAt = attrs?[.creationDate] as? Date ?? Date()

                    let fileType: FileType
                    let ext = url.pathExtension.lowercased()
                    if ["png", "jpg", "jpeg", "webp"].contains(ext) { fileType = .image }
                    else if ext == "pdf" { fileType = .pdf }
                    else if ["mp4", "mov", "avi"].contains(ext) { fileType = .video }
                    else { fileType = .other }

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
            AppLogError("加载文件列表失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 删除
    func deleteFile(_ file: DownloadedFile) {
        do {
            try FileManager.default.removeItem(at: file.fileURL)
            files.removeAll { $0.id == file.id }
        } catch {
            AppLogError("删除文件失败: \(error.localizedDescription)")
        }
    }

    func deleteFiles(_ targets: [DownloadedFile]) {
        for file in targets { deleteFile(file) }
    }

    func deleteAllFiles() {
        deleteFiles(files)
    }

    // MARK: - 重命名
    @discardableResult
    func rename(_ file: DownloadedFile, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let ext = file.fileURL.pathExtension
        let target = file.fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(trimmed)
            .appendingPathExtension(ext)

        do {
            try FileManager.default.moveItem(at: file.fileURL, to: target)
            loadFiles()
            return true
        } catch {
            AppLogError("重命名失败: \(error.localizedDescription)")
            return false
        }
    }
}
