//  存储管理页面 

import SwiftUI
import Charts

struct StorageManagerView: View {
    @StateObject private var cacheManager = WebCacheManager()       //  缓存管理器实例
    @State private var selectedTypes: Set<String> = []              //  选中的缓存类型集合
    @State private var showClearConfirm = false                     //  是否显示清理确认弹窗
    @State private var clearSuccess = false                         //  是否显示清理成功提示
    
    var body: some View {
        List {
            chartSection
            cacheListSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("存储管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("清理选中") {
                    showClearConfirm = true
                }
                .disabled(selectedTypes.isEmpty || cacheManager.isLoading)
            }
        }
        .confirmationDialog("确认清理", isPresented: $showClearConfirm) {
            Button("清理 \(selectedTypes.count) 项缓存", role: .destructive) {
                Task {
                    let success = await cacheManager.clearSelected(types: selectedTypes)
                    if success {
                        selectedTypes.removeAll()
                        clearSuccess = true
                        cacheManager.fetchCacheSizes()
                    }
                }
            }
        } message: {
            Text("此操作不可撤销，确定要清理选中的缓存类型吗？")
        }
        .alert("清理完成", isPresented: $clearSuccess) {
            Button("好的", role: .cancel) {}
        }
        .onAppear {
            cacheManager.fetchCacheSizes()
        }
    }
    
    // 顶部扇形图区域
    private var chartSection: some View {
        Section {
            VStack(spacing: 16) {
                if cacheManager.isLoading {
                    ProgressView("正在计算存储...")
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                } else {
                    StoragePieChart(items: cacheManager.cacheItems)
                        .frame(height: 220)
                    
                    HStack {
                        Text("App 总存储占用")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(cacheManager.totalFormattedSize)
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 8)
        } header: {
            HStack {
                Text("存储概览")
                Spacer()
                Button {
                    cacheManager.fetchCacheSizes()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }
        }
    }
    
    // 底部可选择清理列表
    private var cacheListSection: some View {
        Section {
            // 有占用的项正常展示
            ForEach(cacheManager.cacheItems.filter({ $0.size > 0 })) { item in
                cacheRow(for: item)
            }
            
            // 无占用的项折叠为一行提示
            let zeroItems = cacheManager.cacheItems.filter({ $0.size == 0 })
            if !zeroItems.isEmpty {
                HStack {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("\(zeroItems.count) 项暂无占用")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("选择要清理的类型")
        }
    }
    
    private func cacheRow(for item: CacheItem) -> some View {
        let isSelected = selectedTypes.contains(item.type)
        
        return HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary.opacity(0.5))
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
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
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedTypes.remove(item.type)
                } else {
                    selectedTypes.insert(item.type)
                }
            }
        }
    }
}

// 扇形图组件
struct StoragePieChart: View {
    let items: [CacheItem]
    
    /// 过滤掉内存缓存(-1)和无占用(0)的项
    private var chartData: [CacheItem] {
        items.filter { $0.size > 0 }
    }
    
    var body: some View {
        if chartData.isEmpty {
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
                .chartLegend(.hidden)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 160)
                
                // 自定义图例
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(chartData.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(ChartColors.color(for: index))
                                .frame(width: 10, height: 10)
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
        }
    }
}

// 图表配色
enum ChartColors {
    private static let palette: [Color] = [
        .blue, .orange, .green, .red, .purple,
        .pink, .yellow, .teal, .indigo, .mint
    ]
    
    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }
}
