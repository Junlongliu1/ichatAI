// FilesTabView.swift
//  文件管理视图
import SwiftUI
import QuickLook

struct FilesTabView: View {
    @StateObject private var fileManager = DownloadedFileManager()      // 下载文件管理器
    @State private var selectedFile: URL?                               // 当前选中的文件 URL，用于 QuickLook 预览
    @State private var showDeleteAllAlert = false                       // 是否显示清空所有文件的确认弹窗

    var body: some View {
        VStack(spacing: 0) {
            if !fileManager.files.isEmpty {
                categorySelector
            }

            Group {
                if fileManager.filteredFiles.isEmpty {
                    emptyStateView
                } else {
                    fileList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !fileManager.files.isEmpty {
                bottomInfoBar
            }
        }
        .navigationTitle("我的文件")
        .toolbar { toolbarContent }
        .quickLookPreview($selectedFile)
        .alert("确认清空", isPresented: $showDeleteAllAlert) {
            Button("取消", role: .cancel) {}
            Button("清空所有文件", role: .destructive) {
                withAnimation(.spring(response: 0.4)) {
                    fileManager.deleteAllFiles()
                }
            }
        } message: {
            Text("此操作不可恢复，确定要删除所有下载的文件吗？")
        }
    }
    
    /// 底部文件统计信息栏（安全地显示在 TabBar 上方）
    private var bottomInfoBar: some View {
        HStack {
            Text("\(fileManager.filteredFiles.count) / \(fileManager.files.count) 个文件")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            let totalSize = fileManager.filteredFiles.reduce(Int64(0)) { $0 + $1.fileSize }
            Text(formatTotalSize(totalSize))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
    
    // 分类选择器
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FileCategory.allCases) { category in
                        CategoryChip(
                        category: category,
                        isSelected: fileManager.selectedCategory == category,
                        count: fileManager.count(for: category)
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            fileManager.selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(
                fileManager.selectedCategory == .all ? "暂无下载文件" : "该分类下暂无文件",
                systemImage: fileManager.selectedCategory.icon
            )
        } description: {
            Text(fileManager.selectedCategory == .all
                 ? "从豆包下载的图片、文档将显示在这里"
                 : "试试切换其他分类查看")
        } actions: {
            if fileManager.selectedCategory != .all {
                Button("查看全部") {
                    withAnimation { fileManager.selectedCategory = .all }
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    fileManager.loadFiles()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // 文件列表视图
    @ViewBuilder
    private var fileList: some View {
        if fileManager.selectedCategory == .image {
            imageGridView
        } else {
            fileListView
        }
    }
    
    // 图片网格视图
    private let imageGridColumns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    private var imageGridView: some View {
        ScrollView {
            LazyVGrid(columns: imageGridColumns, spacing: 8) {
                ForEach(fileManager.filteredFiles) { file in
                    ImageGridItem(file: file)
                        .onTapGesture { selectedFile = file.fileURL }
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation { fileManager.deleteFile(file) }
                            } label: {
                                Label("删除", systemImage: "trash.fill")
                            }
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .refreshable { fileManager.loadFiles() }
    }
    
    // 列表视图
    private var fileListView: some View {
        List {
            ForEach(fileManager.filteredFiles) { file in
                FileRowView(file: file)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedFile = file.fileURL }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.35)) {
                                fileManager.deleteFile(file)
                            }
                        } label: {
                            Label("删除", systemImage: "trash.fill")
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .refreshable { fileManager.loadFiles() }
    }
    
    // Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !fileManager.files.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { fileManager.loadFiles() } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteAllAlert = true } label: {
                        Label("清空所有文件", systemImage: "trash.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
    }
    
    // 格式化总文件大小
    private func formatTotalSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB]
        return "共 \(formatter.string(fromByteCount: size))"
    }
}
// 分类标签组件
private struct CategoryChip: View {
    let category: FileCategory
    let isSelected: Bool
    let count: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.caption.weight(.semibold))
            Text(category.rawValue)
                .font(.subheadline.weight(.medium))
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        isSelected ? .white.opacity(0.3) : .secondary.opacity(0.15),
                        in: Capsule()
                    )
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
        )
    }
}

// 图片网格项
private struct ImageGridItem: View {
    let file: DownloadedFile
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            FileThumbnailView(file: file, width: nil, height: 100)
                .frame(maxWidth: .infinity)
            .clipped()
            
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
            
            Text(file.fileName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// 文件行视图
private struct FileRowView: View {
    let file: DownloadedFile
    
    var body: some View {
        HStack(spacing: 14) {
            thumbnailView
            
            fileInfoView
            
            Spacer(minLength: 0)
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 8)
    }
    
    // 缩略图 / 图标
    @ViewBuilder
    private var thumbnailView: some View {
        if file.fileType == .image {
            FileThumbnailView(file: file, width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(lineWidth: 0.5)
                    .foregroundStyle(.black.opacity(0.08))
            )
        } else {
            FileThumbnailView(file: file, width: 56, height: 56)
        }
    }
    
    // 文件信息
    private var fileInfoView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(displayName)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            
            HStack(spacing: 6) {
                fileTypeBadge
                
                Text(formatFileSize(file.fileSize))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                
                Circle()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 3, height: 3)
                
                Text(formatDate(file.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // 显示名称（去掉前缀和时间戳）
    private var displayName: String {
        // 去掉 doubao_ 前缀和时间戳，显示更友好的名称
        let name = file.fileName
        if name.hasPrefix("doubao_"),
           let dotRange = name.range(of: ".", options: .backwards) {
            let stem = String(name[name.startIndex..<dotRange.lowerBound])
            // 尝试提取可读部分
            let parts = stem.split(separator: "_")
            if parts.count >= 2 {
                return parts.dropFirst().joined(separator: "_") + "." + file.fileURL.pathExtension
            }
        }
        return name
    }
    
    // 文件类型徽章
    private var fileTypeBadge: some View {
        Text(file.fileType.label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(file.fileType.color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(file.fileType.color.opacity(0.1), in: Capsule())
    }
    
    // 格式化文件大小
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        return formatter.string(fromByteCount: size)
    }
    
    // 格式化日期为相对时间字符串
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
