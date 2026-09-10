// StorageManagerView.swift
// 存储管理页面
import SwiftUI
import Charts

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

    private var selectedTotalSize: Int64 {
        nonEmptyItems
            .filter { selectedTypes.contains($0.type) }
            .reduce(0) { $0 + $1.size }
    }

    // MARK: - Body
    var body: some View {
        List {
            chartSection
            cacheListSection
            clearSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("存储管理")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - 顶部概览
    private var chartSection: some View {
        Section {
            VStack(spacing: 16) {
                if cacheManager.isLoading {
                    ProgressView("正在计算存储...")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    StoragePieChart(items: cacheManager.cacheItems)
                        .frame(height: 220)

                    Divider()

                    HStack {
                        Text("App 总存储占用")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(cacheManager.totalFormattedSize)
                            .font(.title3.bold())
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 4)
                    .animation(.easeInOut(duration: 0.25), value: cacheManager.totalFormattedSize)
                }
            }
            .padding(.vertical, 8)
        } header: {
            HStack {
                Text("存储概览")
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cacheManager.fetchCacheSizes()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                }
                .disabled(cacheManager.isLoading)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 可选择清理列表
    private var cacheListSection: some View {
        Section {
            ForEach(nonEmptyItems) { item in
                cacheRow(for: item)
            }

            if !emptyItems.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("\(emptyItems.count) 项暂无占用")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            HStack {
                Text("选择要清理的类型")
                Spacer()
                if !nonEmptyItems.isEmpty {
                    Button(isAllSelected ? "取消全选" : "全选") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isAllSelected {
                                selectedTypes.removeAll()
                            } else {
                                selectedTypes = Set(nonEmptyItems.map(\.type))
                            }
                        }
                    }
                    .font(.caption)
                    .textCase(nil)
                }
            }
        } footer: {
            if nonEmptyItems.isEmpty && !cacheManager.isLoading {
                Text("暂无缓存可清理，已为你保持最佳状态 🎉")
            }
        }
    }

    private var isAllSelected: Bool {
        !nonEmptyItems.isEmpty && selectedTypes.count == nonEmptyItems.count
    }

    // MARK: - 底部清理按钮
    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Label(
                        selectedTypes.isEmpty
                            ? "清理选中缓存"
                            : "清理选中缓存（\(selectedTypes.count) 项 · \(formatSize(selectedTotalSize))）",
                        systemImage: "trash.fill"
                    )
                    .font(.body.weight(.semibold))
                    Spacer()
                }
            }
            .disabled(selectedTypes.isEmpty || cacheManager.isLoading)
        } footer: {
            if selectedTypes.isEmpty {
                Text("请先在上方选择要清理的缓存类型。")
            }
        }
    }

    // MARK: - 缓存行
    private func cacheRow(for item: CacheItem) -> some View {
        let isSelected = selectedTypes.contains(item.type)

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedTypes.remove(item.type)
                } else {
                    selectedTypes.insert(item.type)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary.opacity(0.5))
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(item.type)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(item.formattedSize)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected
                ? Color.accentColor.opacity(0.08)
                : Color(UIColor.secondarySystemGroupedBackground)
        )
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

// MARK: - 扇形图组件
struct StoragePieChart: View {
    let items: [CacheItem]

    /// 有磁盘占用的项（排除内存缓存 -1 与空项）
    private var chartData: [CacheItem] {
        items.filter { $0.size > 0 }
    }

    /// 名称 → 颜色 的稳定映射，图例与扇区共用
    private var colorMapping: [(name: String, color: Color)] {
        chartData.enumerated().map { index, item in
            (item.name, ChartColors.color(for: index))
        }
    }

    private var colorDomain: [String] {
        colorMapping.map(\.name)
    }

    private var colorRange: [Color] {
        colorMapping.map(\.color)
    }

    var body: some View {
        if chartData.isEmpty {
            emptyState
        } else {
            HStack(spacing: 16) {
                Chart(chartData) { item in
                    SectorMark(
                        angle: .value("大小", item.size),
                        innerRadius: .ratio(0.62),
                        angularInset: 2.0
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("类型", item.name))
                }
                // ✅ 关键：显式绑定 domain/range，保证图例与扇区颜色一致
                .chartForegroundStyleScale(domain: colorDomain, range: colorRange)
                .chartLegend(.hidden)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 160)

                legend
            }
            .padding(.horizontal, 4)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(colorMapping, id: \.name) { entry in
                HStack(spacing: 8) {
                    Circle()
                        .fill(entry.color)
                        .frame(width: 10, height: 10)
                    Text(entry.name)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 30)
                .frame(width: 160, height: 160)
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("无磁盘占用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
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
