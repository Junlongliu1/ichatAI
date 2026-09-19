// HomeView.swift
// 首页主视图 — iOS 26+ Liquid Glass 设计
// 优化点：
//  1. 每个服务独立 WebView 状态，切换不重建
//  2. 顶部加载进度条
//  3. 加载失败错误页 + 重试
import SwiftUI

struct HomeView: View {
    @StateObject private var serviceManager = AIServiceManager.shared
    @State private var selectedService: AIService
    @State private var activeSheet: ActiveSheet?

    /// 每个服务独立的状态，切换服务不丢失
    @State private var serviceStates: [String: WebViewState] = [:]
    /// 已访问过的服务 ID（保持顺序，用于 ZStack 渲染）
    @State private var visitedServiceIDs: [String] = []

    enum ActiveSheet: Identifiable {
        case files, settings
        var id: Int { hashValue }
    }

    init() {
        let defaultService = AIServiceManager.shared.defaultService
        _selectedService = State(initialValue: defaultService)
        _visitedServiceIDs = State(initialValue: [defaultService.id])
        _serviceStates = State(initialValue: [defaultService.id: WebViewState()])
    }

    /// 当前选中服务的状态
    private var currentState: WebViewState {
        serviceStates[selectedService.id] ?? WebViewState()
    }

    var body: some View {
        ZStack {
            // 已访问服务的 WebView，按顺序渲染，只显示当前选中的那个
            ForEach(visitedServiceIDs, id: \.self) { serviceID in
                if let service = serviceManager.allServices.first(where: { $0.id == serviceID }) {
                    AIWebView(
                        state: stateBinding(for: serviceID),
                        currentURL: service.url
                    )
                    .opacity(serviceID == selectedService.id ? 1 : 0)
                    .allowsHitTesting(serviceID == selectedService.id)
                }
            }

            // 加载指示器（仅在尚无进度时显示）
            if currentState.isLoading
                && currentState.error == nil
                && currentState.progress < 0.1 {
                LoadingOverlay(serviceName: selectedService.name)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }

            // 错误覆盖层
            if let error = currentState.error {
                ErrorOverlay(message: error, onRetry: retry)
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // 顶部加载进度条
            if currentState.isLoading
                && currentState.progress > 0.05
                && currentState.progress < 1.0 {
                ProgressView(value: currentState.progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .background(.ultraThinMaterial)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassBottomBar(
                services: serviceManager.visibleServices,
                selectedService: $selectedService,
                onNavigate: handleNavigate
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            validateSelectedService()
        }
        .onChange(of: serviceManager.visibleServices.map(\.id)) { _, _ in
            validateSelectedService()
        }
        .onChange(of: selectedService) { _, newValue in
            ensureVisited(newValue)
        }
        .fullScreenCover(item: $activeSheet) { sheet in
            FullScreenPageContainer(sheet: sheet) {
                activeSheet = nil
            }
        }
    }

    // MARK: - State binding
    private func stateBinding(for serviceID: String) -> Binding<WebViewState> {
        Binding(
            get: { serviceStates[serviceID] ?? WebViewState() },
            set: { serviceStates[serviceID] = $0 }
        )
    }

    /// 首次访问某服务时，懒加载地初始化状态并加入渲染列表
    private func ensureVisited(_ service: AIService) {
        if !visitedServiceIDs.contains(service.id) {
            visitedServiceIDs.append(service.id)
        }
        if serviceStates[service.id] == nil {
            serviceStates[service.id] = WebViewState()
        }
    }

    // MARK: - Actions
    private func handleNavigate(to target: ActiveSheet) {
        activeSheet = target
    }

    private func validateSelectedService() {
        let visible = serviceManager.visibleServices
        guard !visible.contains(where: { $0.id == selectedService.id }) else { return }
        selectedService = visible.first ?? serviceManager.defaultService
    }

    /// 触发当前服务重新加载
    private func retry() {
        guard var state = serviceStates[selectedService.id] else { return }
        state.reloadToken = UUID()
        state.error = nil
        state.isLoading = true
        state.progress = 0
        serviceStates[selectedService.id] = state
    }
}

// MARK: - Liquid Glass 底部工具条
struct GlassBottomBar: View {
    let services: [AIService]
    @Binding var selectedService: AIService
    let onNavigate: (HomeView.ActiveSheet) -> Void

    private let buttonSize: CGFloat = 38

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 8) {
                serviceMenu

                Spacer(minLength: 0)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onNavigate(.files)
                } label: {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: buttonSize, height: buttonSize)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("文件")

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onNavigate(.settings)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: buttonSize, height: buttonSize)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("设置")
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
    }

    // MARK: 服务菜单
    private var serviceMenu: some View {
        Menu {
            ForEach(services) { service in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    selectedService = service
                } label: {
                    HStack {
                        Text(service.name)
                        if service.id == selectedService.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(selectedService.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: buttonSize)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("切换 AI 服务，当前 \(selectedService.name)")
    }
}

// MARK: - 全屏页面容器
private struct FullScreenPageContainer: View {
    let sheet: HomeView.ActiveSheet
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch sheet {
                case .files:    FilesTabView(onDismiss: onDismiss)
                case .settings: SettingsView(onDismiss: onDismiss)
                }
            }
        }
    }
}

// MARK: - 加载动画覆盖层
private struct LoadingOverlay: View {
    let serviceName: String
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                        .scaleEffect(isAnimating ? 1.4 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
            }
            Text("正在加载 \(serviceName)...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .onAppear { isAnimating = true }
    }
}

// MARK: - 错误覆盖层
private struct ErrorOverlay: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("页面无法加载")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onRetry()
            } label: {
                Label("重新加载", systemImage: "arrow.clockwise")
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
