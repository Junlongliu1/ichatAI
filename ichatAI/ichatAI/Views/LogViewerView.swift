// LogViewerView.swift
// 调试日志查看器
import SwiftUI

struct LogViewerView: View {
    @ObservedObject private var logManager = LogManager.shared

    @State private var autoScroll = true
    @State private var showClearConfirm = false
    @State private var searchText = ""

    /// 统一 Toast 状态（复制、刷新、清空共用）
    @State private var toastMessage: String?

    /// 解析后的日志行，避免 body 反复 split
    @State private var logLines: [LogLine] = []

    @State private var toastTask: Task<Void, Never>?

    // MARK: - 日志行模型
    struct LogLine: Identifiable {
        let id: Int
        let text: String
        let level: Level

        enum Level {
            case debug, warning, error, plain

            var color: Color {
                switch self {
                case .debug:   return .secondary
                case .warning: return .orange
                case .error:   return .red
                case .plain:   return .primary
                }
            }
        }

        init(id: Int, text: String) {
            self.id = id
            self.text = text
            let upper = text.uppercased()
            if upper.contains("[ERROR]") || upper.contains("❌") {
                self.level = .error
            } else if upper.contains("[WARN]") || upper.contains("⚠️") {
                self.level = .warning
            } else if upper.contains("[DEBUG]") {
                self.level = .debug
            } else {
                self.level = .plain
            }
        }
    }

    private var filteredLines: [LogLine] {
        guard !searchText.isEmpty else { return logLines }
        let q = searchText.lowercased()
        return logLines.filter { $0.text.lowercased().contains(q) }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            logContentArea
            Divider()
            bottomActionBar
        }
        .navigationTitle("调试日志")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索日志内容"
        )
        .task {
            logManager.loadTodayLog()
            refreshLines()
        }
        .onChange(of: logManager.logContent) { _, _ in
            refreshLines()
        }
        .onDisappear {
            toastTask?.cancel()
        }
        // 复制、刷新、清空共用顶部 Toast
        .overlay(alignment: .top) {
            if let message = toastMessage {
                ToastView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // 居中确认弹窗
        .alert("确认清空日志？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空今日日志", role: .destructive) {
                performClear()
            }
        } message: {
            Text("此操作不可撤销，今日的日志文件将被删除。")
        }
    }

    // MARK: - 顶部控制栏
    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                autoScroll.toggle()
            } label: {
                Label(
                    "自动滚动",
                    systemImage: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(autoScroll ? .accentColor : .secondary)

            Spacer()

            Text("\(filteredLines.count) 行")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 日志内容区
    private var logContentArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if filteredLines.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(filteredLines) { line in
                            logLineView(line: line)
                        }
                    }

                    // 底部锚点
                    Color.clear
                        .frame(height: 1)
                        .id("logBottom")
                }
                .padding(.vertical, 4)
            }
            .onChange(of: filteredLines.count) { _, _ in
                guard autoScroll, !filteredLines.isEmpty else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("logBottom", anchor: .bottom)
                }
            }
            .onChange(of: autoScroll) { _, isOn in
                guard isOn, !filteredLines.isEmpty else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("logBottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 单行日志
    private func logLineView(line: LogLine) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(line.id + 1)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)

            Text(line.text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(line.level.color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            line.id.isMultiple(of: 2)
                ? Color.clear
                : Color(.secondarySystemFill).opacity(0.35)
        )
    }

    // MARK: - 空状态
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(
                searchText.isEmpty ? "暂无日志" : "没有匹配的日志",
                systemImage: searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass"
            )
        } description: {
            Text(
                searchText.isEmpty
                    ? "当应用运行时，日志将显示在这里"
                    : "试试其它关键词"
            )
        } actions: {
            if !searchText.isEmpty {
                Button("清除搜索") { searchText = "" }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - 底部操作栏
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            actionButton(
                title: "复制",
                systemImage: "doc.on.doc",
                tint: nil,
                action: copyLogs
            )
            .disabled(logLines.isEmpty)

            actionButton(
                title: "刷新",
                systemImage: "arrow.clockwise",
                tint: nil,
                action: performRefresh
            )

            actionButton(
                title: "清空",
                systemImage: "trash",
                tint: .red,
                role: .destructive,
                action: { showClearConfirm = true }
            )
            .disabled(logLines.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color?,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(tint)
    }

    // MARK: - 日志解析
    private func refreshLines() {
        let content = logManager.logContent
        guard !content.isEmpty else {
            logLines = []
            return
        }
        logLines = content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .enumerated()
            .map { index, slice in
                LogLine(id: index, text: String(slice))
            }
    }

    // MARK: - Actions

    /// 刷新：重载日志 + 顶部 Toast 提示
    private func performRefresh() {
        logManager.loadTodayLog()
        refreshLines()
        showToast("已刷新")
    }

    /// 清空：确认后执行 + 顶部 Toast 提示
    private func performClear() {
        logManager.clearTodayLog()
        refreshLines()
        showToast("已清空日志")
    }

    /// 复制：写入剪贴板 + 顶部 Toast 提示
    private func copyLogs() {
        guard !logManager.logContent.isEmpty else { return }
        UIPasteboard.general.string = logManager.logContent
        showToast("已复制到剪贴板")
    }

    /// 统一 Toast 触发方法（复制、刷新、清空共用）
    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toastMessage = message
        }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation { toastMessage = nil }
            }
        }
    }
}

// MARK: - Toast
struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.82), in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .padding(.top, 8)
    }
}
