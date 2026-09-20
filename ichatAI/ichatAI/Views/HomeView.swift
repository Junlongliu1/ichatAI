// HomeView.swift
import SwiftUI
import UIKit

struct HomeView: View {
    private let serviceManager = AIServiceManager.shared
    private let themeManager = ThemeManager.shared
    private let network = NetworkMonitor.shared

    @State private var selectedService: AIService
    @State private var activeSheet: ActiveSheet?

    @State private var serviceStates: [String: WebViewState] = [:]
    @State private var visitedServiceIDs: [String] = []
    /// B6：ID → AIService 索引，避免每次渲染都 first(where:)
    @State private var serviceIndex: [String: AIService] = [:]

    private let maxCachedWebViews = 3

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

    private var currentState: WebViewState {
        serviceStates[selectedService.id] ?? WebViewState()
    }

    var body: some View {
        ZStack {
            ForEach(visitedServiceIDs, id: \.self) { serviceID in
                if let service = serviceIndex[serviceID] {
                    AIWebView(
                        state: stateBinding(for: serviceID),
                        currentURL: service.url,
                        uiStyle: themeManager.current.uiStyle,
                        isActive: serviceID == selectedService.id
                    )
                    .opacity(serviceID == selectedService.id ? 1 : 0)
                    .allowsHitTesting(serviceID == selectedService.id)
                }
            }

            if currentState.isLoading
                && currentState.error == nil
                && currentState.progress < 0.1 {
                LoadingOverlay(serviceName: selectedService.name)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }

            if let error = currentState.error {
                ErrorOverlay(message: error, onRetry: retry)
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if !network.isOnline {
                    OfflineBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if currentState.isLoading
                    && currentState.progress > 0.05
                    && currentState.progress < 1.0 {
                    ProgressView(value: currentState.progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .background(.ultraThinMaterial)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: network.isOnline)
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
            rebuildServiceIndex()
            validateSelectedService()
        }
        .onChange(of: serviceManager.allServices.map(\.id)) { _, _ in
            rebuildServiceIndex()
            validateSelectedService()
        }
        .onChange(of: serviceManager.visibleServices.map(\.id)) { _, _ in
            validateSelectedService()
        }
        .onChange(of: selectedService) { _, newValue in
            ensureVisited(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didReceiveMemoryWarningNotification
        )) { _ in
            handleMemoryWarning()
        }
        .fullScreenCover(item: $activeSheet) { sheet in
            FullScreenPageContainer(sheet: sheet) { activeSheet = nil }
        }
    }

    private func rebuildServiceIndex() {
        var idx: [String: AIService] = [:]
        for s in serviceManager.allServices { idx[s.id] = s }
        serviceIndex = idx
    }

    private func stateBinding(for serviceID: String) -> Binding<WebViewState> {
        Binding(
            get: { serviceStates[serviceID] ?? WebViewState() },
            set: { serviceStates[serviceID] = $0 }
        )
    }

    private func ensureVisited(_ service: AIService) {
        visitedServiceIDs.removeAll { $0 == service.id }
        visitedServiceIDs.append(service.id)
        if serviceStates[service.id] == nil {
            serviceStates[service.id] = WebViewState()
        }
        while visitedServiceIDs.count > maxCachedWebViews {
            guard let oldest = visitedServiceIDs.first, oldest != selectedService.id else { break }
            visitedServiceIDs.removeFirst()
            serviceStates[oldest] = nil
        }
    }

    private func handleMemoryWarning() {
        AppLogWarn("[HomeView] 内存警告，回收非当前 WebView")
        let currentID = selectedService.id
        for id in visitedServiceIDs where id != currentID {
            serviceStates[id] = nil
        }
        visitedServiceIDs = [currentID]
    }

    private func handleNavigate(to target: ActiveSheet) {
        activeSheet = target
    }

    private func validateSelectedService() {
        let visible = serviceManager.visibleServices
        guard !visible.contains(where: { $0.id == selectedService.id }) else { return }
        selectedService = visible.first ?? serviceManager.defaultService
    }

    private func retry() {
        guard var state = serviceStates[selectedService.id] else { return }
        state.reloadToken = UUID()
        state.error = nil
        state.isLoading = true
        state.progress = 0
        serviceStates[selectedService.id] = state
    }
}

// MARK: - 底部工具条（保持不变）
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

// MARK: - 全屏容器（去嵌套 NavigationStack）
private struct FullScreenPageContainer: View {
    let sheet: HomeView.ActiveSheet
    let onDismiss: () -> Void

    var body: some View {
        Group {
            switch sheet {
            case .files:
                NavigationStack {
                    FilesTabView(onDismiss: onDismiss)
                }
            case .settings:
                SettingsView(onDismiss: onDismiss)
            }
        }
    }
}

// MARK: - Loading / Error（保持不变）
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
