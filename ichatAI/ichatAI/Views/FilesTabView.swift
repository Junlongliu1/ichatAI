// FilesTabView.swift
// 文件管理视图
import SwiftUI
import QuickLook

struct FilesTabView: View {
    let onDismiss: () -> Void

    @StateObject private var fileManager = DownloadedFileManager()
    @State private var selectedFile: URL?
    @State private var showDeleteAllAlert = false

    private let imageGridColumns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            if !fileManager.files.isEmpty {
                categorySelector
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !fileManager.files.isEmpty {
                bottomInfoBar
            }
        }
        .navigationTitle("我的文件")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onDismiss) {
                    Label("返回", systemImage: "chevron.left")
                        .font(.body.weight(.semibold))
                }
            }
            if !fileManager.files.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
        }
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

    // MARK: - Content 分流
    @ViewBuilder
    private var content: some View {
        if fileManager.filteredFiles.isEmpty {
            emptyStateView
        } else if fileManager.selectedCategory == .image {
            imageGridView
        } else {
            fileListView
        }
    }

    // MARK: - 底部统计栏
    private var bottomInfoBar: some View {
        HStack {
            Text("\(fileManager.filteredFiles.count) / \(fileManager.files.count) 个文件")
            Spacer()
            Text("共 \(FileFormatters.size.string(fromByteCount: filteredTotalSize))")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private var filteredTotalSize: Int64 {
        fileManager.filteredFiles.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - 工具栏溢出菜单
    private var overflowMenu: some View {
        Menu {
            Button {
                fileManager.loadFiles()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            Divider()
            Button(role: .destructive) {
                showDeleteAllAlert = true
            } label: {
                Label("清空所有文件", systemImage: "trash.fill")
            }
        } label: {
            Image(systemName: "ellipsis")
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: - 分类选择器
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FileCategory.allCases) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            fileManager.selectedCategory = category
                        }
                    } label: {
                        CategoryChip(
                            category: category,
                            isSelected: fileManager.selectedCategory == category,
                            count: fileManager.count(for: category)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - 空状态
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(
                fileManager.selectedCategory == .all ? "暂无下载文件" : "该分类下暂无文件",
                systemImage: fileManager.selectedCategory.icon
            )
        } description: {
            Text(
                fileManager.selectedCategory == .all
                    ? "从 AI 服务下载的图片、文档将显示在这里"
                    : "试试切换其他分类查看"
            )
        } actions: {
            if fileManager.selectedCategory == .all {
                Button {
                    fileManager.loadFiles()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            } else {
                Button("查看全部") {
                    withAnimation { fileManager.selectedCategory = .all }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - 图片网格
    private var imageGridView: some View {
        ScrollView {
            LazyVGrid(columns: imageGridColumns, spacing: 8) {
                ForEach(fileManager.filteredFiles) { file in
                    Button {
                        selectedFile = file.fileURL
                    } label: {
                        ImageGridItem(file: file)
                    }
                    .buttonStyle(.plain)
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

    // MARK: - 列表
    private var fileListView: some View {
        List {
            ForEach(fileManager.filteredFiles) { file in
                Button {
                    selectedFile = file.fileURL
                } label: {
                    FileRowView(file: file)
                }
                .buttonStyle(.plain)
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
}

// MARK: - 分类标签
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
                        isSelected ? AnyShapeStyle(.white.opacity(0.3))
                                   : AnyShapeStyle(.secondary.opacity(0.15)),
                        in: Capsule()
                    )
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.1)
            )
        )
        .contentShape(Capsule())
    }
}

// MARK: - 图片网格项
private struct ImageGridItem: View {
    let file: DownloadedFile

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            FileThumbnailView(file: file, width: nil, height: 100)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
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

// MARK: - 文件行
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
        .contentShape(Rectangle())
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

                Text(FileFormatters.size.string(fromByteCount: file.fileSize))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Circle()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 3, height: 3)

                Text(FileFormatters.relativeDate.localizedString(for: file.createdAt, relativeTo: Date()))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var displayName: String {
        let name = file.fileName
        let pattern = #"^[A-Za-z]+_\d{8,13}_"#
        if let range = name.range(of: pattern, options: .regularExpression) {
            let remainder = String(name[range.upperBound...])
            if !remainder.isEmpty { return remainder }
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
}
