// FilesTabView.swift
import SwiftUI
import QuickLook

struct FilesTabView: View {
    let onDismiss: () -> Void

    @State private var fileManager = DownloadedFileManager()
    @State private var selectedFile: URL?
    @State private var showDeleteAllAlert = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var renameTarget: DownloadedFile?
    @State private var renameText = ""

    private let gridColumns = [GridItem(.adaptive(minimum: 108), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !fileManager.files.isEmpty {
                    searchAndSortBar
                    categoryChips
                }
                contentView
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isSelecting ? "已选 \(selectedIDs.count)" : "我的文件")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isSelecting {
                    Button("取消") {
                        isSelecting = false
                        selectedIDs.removeAll()
                    }
                } else {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("返回")
                }
            }
            if !fileManager.files.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting {
                        Button("全选") { toggleSelectAll() }
                    } else {
                        Menu {
                            Button {
                                isSelecting = true
                            } label: {
                                Label("多选", systemImage: "checkmark.circle")
                            }
                            Button(role: .destructive) {
                                showDeleteAllAlert = true
                            } label: {
                                Label("清空所有文件", systemImage: "trash.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis").symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelecting {
                selectionBottomBar
            } else if !fileManager.files.isEmpty {
                bottomGlassBar
            }
        }
        .quickLookPreview($selectedFile)
        .alert("确认清空", isPresented: $showDeleteAllAlert) {
            Button("取消", role: .cancel) {}
            Button("清空所有文件", role: .destructive) {
                withAnimation(.spring(response: 0.4)) { fileManager.deleteAllFiles() }
            }
        } message: {
            Text("此操作不可恢复，确定要删除所有下载的文件吗？")
        }
        .alert("重命名", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("新名称", text: $renameText)
            Button("取消", role: .cancel) { renameTarget = nil }
            Button("确定") {
                if let target = renameTarget {
                    fileManager.rename(target, to: renameText)
                }
                renameTarget = nil
            }
        }
    }

    // MARK: - 搜索 + 排序
    private var searchAndSortBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索文件", text: $fileManager.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08), in: Capsule())

            Menu {
                Picker("排序", selection: $fileManager.sortOption) {
                    ForEach(FileSortOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    // MARK: - 分类 chips（原样保留，去掉 padding 已由外层处理）
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
            Button {
                fileManager.loadFiles()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glass)
        }
        .padding(.top, 40)
    }

    // MARK: - 图片网格
    private var imageGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(fileManager.filteredFiles) { file in
                Button { handleTap(file) } label: {
                    ImageGridCard(file: file, isSelecting: isSelecting, isSelected: selectedIDs.contains(file.id))
                }
                .buttonStyle(.plain)
                .contextMenu { contextMenuItems(for: file) }
            }
        }
    }

    // MARK: - 文件列表
    private var fileList: some View {
        LazyVStack(spacing: 10) {
            ForEach(fileManager.filteredFiles) { file in
                Button { handleTap(file) } label: {
                    FileRowCard(file: file, isSelecting: isSelecting, isSelected: selectedIDs.contains(file.id))
                }
                .buttonStyle(.plain)
                .contextMenu { contextMenuItems(for: file) }
            }
        }
    }

    @ViewBuilder
    private func contextMenuItems(for file: DownloadedFile) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedFile = file.fileURL
        } label: {
            Label("预览", systemImage: "eye")
        }

        ShareLink(item: file.fileURL) {
            Label("分享", systemImage: "square.and.arrow.up")
        }

        Button {
            renameText = file.fileName
            renameTarget = file
        } label: {
            Label("重命名", systemImage: "pencil")
        }

        Button(role: .destructive) {
            withAnimation { fileManager.deleteFile(file) }
        } label: {
            Label("删除", systemImage: "trash.fill")
        }
    }

    private func handleTap(_ file: DownloadedFile) {
        if isSelecting {
            if selectedIDs.contains(file.id) { selectedIDs.remove(file.id) }
            else { selectedIDs.insert(file.id) }
        } else {
            selectedFile = file.fileURL
        }
    }

    private func toggleSelectAll() {
        if selectedIDs.count == fileManager.filteredFiles.count {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(fileManager.filteredFiles.map(\.id))
        }
    }

    // MARK: - 底部工具栏（非选择模式）
    private var bottomGlassBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Label {
                        Text("\(fileManager.filteredFiles.count)/\(fileManager.files.count)")
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    } icon: { Image(systemName: "doc.on.doc") }
                    .font(.footnote.weight(.medium))

                    Divider().frame(height: 14)

                    Label {
                        Text(FileFormatters.size.string(fromByteCount: filteredTotalSize))
                            .monospacedDigit()
                    } icon: { Image(systemName: "internaldrive") }
                    .font(.footnote.weight(.medium))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .glassEffect(.regular, in: .capsule)

                Spacer(minLength: 0)

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

    // MARK: - 底部工具栏（多选模式）
    private var selectionBottomBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    let targets = fileManager.filteredFiles.filter { selectedIDs.contains($0.id) }
                    shareItems(targets)
                } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .disabled(selectedIDs.isEmpty)

                Spacer(minLength: 0)

                Button {
                    let targets = fileManager.filteredFiles.filter { selectedIDs.contains($0.id) }
                    withAnimation {
                        fileManager.deleteFiles(targets)
                        selectedIDs.removeAll()
                        isSelecting = false
                    }
                } label: {
                    Label("删除", systemImage: "trash.fill")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 20)
                        .frame(height: 40)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.red).interactive(), in: .capsule)
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func shareItems(_ files: [DownloadedFile]) {
        // ShareLink 在多选场景下不太方便，用 UIActivityViewController
        let urls = files.map(\.fileURL)
        guard !urls.isEmpty else { return }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        root.present(vc, animated: true)
    }

    private var filteredTotalSize: Int64 {
        fileManager.filteredFiles.reduce(0) { $0 + $1.fileSize }
    }
}

// MARK: - 分类 Chip（原样）
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
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            FileThumbnailView(file: file, width: nil, height: 108)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 36)

            Text(file.fileName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.bottom, 5)

            if isSelecting {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? Color.accentColor : .white)
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .white.opacity(0.08),
                              lineWidth: isSelected ? 2 : 0.5)
        )
    }
}

// MARK: - 文件行卡片
private struct FileRowCard: View {
    let file: DownloadedFile
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }

            thumbnailView
            fileInfoView
            Spacer(minLength: 0)
            if !isSelecting {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.10) : .clear)
        )
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
                Circle().fill(.secondary.opacity(0.4)).frame(width: 3, height: 3)
                Text(FileFormatters.relativeDate.localizedString(for: file.createdAt, relativeTo: Date()))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var displayName: String {
        let name = file.fileName
        // 兼容 ai_ 与旧 doubao_ 前缀
        let pattern = #"^(ai|doubao)_\d+_"#
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
