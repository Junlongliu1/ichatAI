// StorageManagerView.swift
// 存储管理 —— iOS 26 液态玻璃
// 使用堆叠横向条替代扇形图，更直观、更贴合 Liquid Glass 风格
import SwiftUI

struct StorageManagerView: View {
    @StateObject private var cacheManager = WebCacheManager()
    @State private var selectedTypes: Set<String> = []
    @State private var showClearConfirm = false
    @State private var clearResult: ClearResult?

    private struct ClearResult: Identifiable {
        let id = UUID()
        let isSuccess: Bool
        let message: String
    }

    // MARK: - 派生数据
    private var nonEmptyItems: [CacheItem] {
        cacheManager.cacheItems.filter { $0.size > 0 }
    }

    private var emptyItems: [CacheItem] {
        cacheManager.cacheItems.filter { $0.size == 0 }
    }

    private var totalSize: Int64 {
        nonEmptyItems.reduce(0) { $0 + $1.size }
    }

    private var selectedTotalSize: Int64 {
        nonEmptyItems
            .filter { selectedTypes.contains($0.type) }
            .reduce(0) { $0 + $1.size }
    }

    private var isAllSelected: Bool {
        !nonEmptyItems.isEmpty && selectedTypes.count == nonEmptyItems.count
    }

    /// 名称 → 颜色 的稳定映射（列表和色带共用）
    private var colorMapping: [String: Color] {
        var mapping: [String: Color] = [:]
        for (index, item) in nonEmptyItems.enumerated() {
            mapping[item.id] = ChartColors.color(for: index)
        }
        return mapping
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewCard
                cacheListCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("存储管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    cacheManager.fetchCacheSizes()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolRenderingMode(.hierarchical)
                        .rotationEffect(.degrees(cacheManager.isLoading ? 360 : 0))
                        .animation(
                            cacheManager.isLoading
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: cacheManager.isLoading
                        )
                }
                .disabled(cacheManager.isLoading)
                .accessibilityLabel("刷新")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !selectedTypes.isEmpty {
                clearBottomBar
            }
        }
        .confirmationDialog(
            "确认清理",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("清理 \(selectedTypes.count) 项缓存", role: .destructive) {
                performClear()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销，确定要清理选中的缓存类型吗？")
        }
        .alert(item: $clearResult) { result in
            Alert(
                title: Text(result.isSuccess ? "清理完成" : "清理失败"),
                message: Text(result.message),
                dismissButton: .default(Text("好的"))
            )
        }
        .task {
            cacheManager.fetchCacheSizes()
        }
    }

    // MARK: - 顶部概览卡
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            if cacheManager.isLoading {
                ProgressView("正在计算存储...")
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                // 总占用
                VStack(alignment: .leading, spacing: 4) {
                    Text("App 总存储占用")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(cacheManager.totalFormattedSize)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: cacheManager.totalFormattedSize)
                }

                // 堆叠色带
                if !nonEmptyItems.isEmpty {
                    StackedBar(items: nonEmptyItems, colorMapping: colorMapping)

                    // 图例（两列）
                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(nonEmptyItems) { item in
                            legendItem(for: item)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private func legendItem(for item: CacheItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(colorMapping[item.id] ?? .gray)
                .frame(width: 9, height: 9)

            Text(item.name)
                .font(.footnote)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(item.formattedSize)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - 缓存列表卡
    private var cacheListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部
            HStack {
                Text("选择要清理的类型")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if !nonEmptyItems.isEmpty {
                    Button(isAllSelected ? "取消全选" : "全选") {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isAllSelected {
                                selectedTypes.removeAll()
                            } else {
                                selectedTypes = Set(nonEmptyItems.map(\.type))
                            }
                        }
                    }
                    .font(.footnote.weight(.medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // 列表
            VStack(spacing: 8) {
                ForEach(nonEmptyItems) { item in
                    CacheRow(
                        item: item,
                        isSelected: selectedTypes.contains(item.type),
                        accentColor: colorMapping[item.id] ?? .accentColor
                    ) {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if selectedTypes.contains(item.type) {
                                selectedTypes.remove(item.type)
                            } else {
                                selectedTypes.insert(item.type)
                            }
                        }
                    }
                }

                if !emptyItems.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.tertiary)
                        Text("\(emptyItems.count) 项暂无占用")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                if nonEmptyItems.isEmpty && !cacheManager.isLoading {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.secondary)
                        Text("暂无缓存可清理，已为你保持最佳状态")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    // MARK: - 底部清理栏
    private var clearBottomBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已选 \(selectedTypes.count) 项")
                        .font(.footnote.weight(.medium))
                    Text(formatSize(selectedTotalSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .glassEffect(.regular, in: .capsule)

                Spacer(minLength: 0)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showClearConfirm = true
                } label: {
                    Label("清理", systemImage: "trash.fill")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 20)
                        .frame(height: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.red).interactive(), in: .capsule)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Actions
    private func performClear() {
        let types = selectedTypes
        Task {
            let success = await cacheManager.clearSelected(types: types)
            if success {
                selectedTypes.removeAll()
                cacheManager.fetchCacheSizes()
                clearResult = ClearResult(
                    isSuccess: true,
                    message: "已清理 \(types.count) 项缓存。"
                )
            } else {
                clearResult = ClearResult(
                    isSuccess: false,
                    message: "部分缓存清理失败，请稍后重试。"
                )
            }
        }
    }

    private func formatSize(_ size: Int64) -> String {
        FileFormatters.size.string(fromByteCount: size)
    }
}

// MARK: - 堆叠横向色带
private struct StackedBar: View {
    let items: [CacheItem]
    let colorMapping: [String: Color]

    private var total: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(items) { item in
                    let ratio = total > 0 ? Double(item.size) / Double(total) : 0
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(colorMapping[item.id] ?? .gray)
                        .frame(width: max(2, geo.size.width * ratio - 2))
                }
            }
        }
        .frame(height: 14)
        .clipShape(Capsule())
    }
}

// MARK: - 缓存行
private struct CacheRow: View {
    let item: CacheItem
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 左侧色条
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 3, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(item.type)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                Text(item.formattedSize)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 图表配色
enum ChartColors {
    private static let palette: [Color] = [
        .blue, .orange, .green, .red, .purple,
        .pink, .yellow, .teal, .indigo, .mint
    ]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }
}
