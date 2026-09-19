// FilesTabView.swift
// 文件管理 —— iOS 26 液态玻璃
import SwiftUI
import QuickLook

struct FilesTabView: View {
    let onDismiss: () -> Void

    @StateObject private var fileManager = DownloadedFileManager()
    @State private var selectedFile: URL?
    @State private var showDeleteAllAlert = false

    private let gridColumns = [GridItem(.adaptive(minimum: 108), spacing: 10)]

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !fileManager.files.isEmpty {
                    categoryChips
                }
                contentView
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)      // 为底部浮动栏预留空间
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("我的文件")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("返回")
            }
            if !fileManager.files.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !fileManager.files.isEmpty {
                bottomGlassBar
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

    // MARK: - 分类选择（横向玻璃胶囊）
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(FileCategory.allCases) { category in
                        let isSelected = fileManager.selectedCategory == category
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                fileManager.selectedCategory = category
                            }
                        } label: {
                            CategoryChipLabel(
                                category: category,
                                count: fileManager.count(for: category),
                                isSelected: isSelected
                            )
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            isSelected
                                ? .regular.tint(Color.accentColor).interactive()
                                : .regular.interactive(),
                            in: .capsule
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var contentView: some View {
        if fileManager.filteredFiles.isEmpty {
            emptyStateView
        } else if fileManager.selectedCategory == .image {
            imageGrid
        } else {
            fileList
        }
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
                .buttonStyle(.glass)
            } else {
                Button("查看全部") {
                    withAnimation { fileManager.selectedCategory = .all }
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - 图片网格
    private var imageGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(fileManager.filteredFiles) { file in
                Button {
                    selectedFile = file.fileURL
                } label: {
                    ImageGridCard(file: file)
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
    }

    // MARK: - 文件列表
    private var fileList: some View {
        LazyVStack(spacing: 10) {
            ForEach(fileManager.filteredFiles) { file in
                Button {
                    selectedFile = file.fileURL
                } label: {
                    FileRowCard(file: file)
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
    }

    // MARK: - 底部浮动玻璃栏
    private var bottomGlassBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                // 统计信息
                HStack(spacing: 10) {
                    Label {
                        Text("\(fileManager.filteredFiles.count)/\(fileManager.files.count)")
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    } icon: {
                        Image(systemName: "doc.on.doc")
                    }
                    .font(.footnote.weight(.medium))

                    Divider().frame(height: 14)

                    Label {
                        Text(FileFormatters.size.string(fromByteCount: filteredTotalSize))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "internaldrive")
                    }
                    .font(.footnote.weight(.medium))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .glassEffect(.regular, in: .capsule)

                Spacer(minLength: 0)

                // 刷新
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    fileManager.loadFiles()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("刷新")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var filteredTotalSize: Int64 {
        fileManager.filteredFiles.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - 溢出菜单
    private var overflowMenu: some View {
        Menu {
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
}

// MARK: - 分类 Chip
private struct CategoryChipLabel: View {
    let category: FileCategory
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.caption.weight(.semibold))

            Text(category.rawValue)
                .font(.subheadline.weight(.medium))

            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        isSelected
                            ? AnyShapeStyle(.white.opacity(0.3))
                            : AnyShapeStyle(.secondary.opacity(0.15)),
                        in: Capsule()
                    )
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Capsule())
    }
}

// MARK: - 图片网格卡片
private struct ImageGridCard: View {
    let file: DownloadedFile

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            FileThumbnailView(file: file, width: nil, height: 108)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 36)

            Text(file.fileName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.bottom, 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - 文件行卡片
private struct FileRowCard: View {
    let file: DownloadedFile

    var body: some View {
        HStack(spacing: 14) {
            thumbnailView
            fileInfoView
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if file.fileType == .image {
            FileThumbnailView(file: file, width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
                )
        } else {
            FileThumbnailView(file: file, width: 56, height: 56)
        }
    }

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

    private var fileTypeBadge: some View {
        Text(file.fileType.label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(file.fileType.color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(file.fileType.color.opacity(0.1), in: Capsule())
    }
}
