// HomeView.swift
// 首页主视图
import SwiftUI

struct HomeView: View {
    @StateObject private var serviceManager = AIServiceManager.shared
    @State private var selectedService: AIService
    @State private var isWebLoading = true
    @State private var isMenuExpanded = false
    @State private var activeSheet: ActiveSheet?

    enum ActiveSheet: Identifiable {
        case files, settings
        var id: Int { hashValue }
    }

    init() {
        _selectedService = State(initialValue: AIServiceManager.shared.defaultService)
    }

    var body: some View {
        ZStack {
            AIWebView(isLoading: $isWebLoading, currentURL: selectedService.url)
                .id(selectedService.id)

            if isWebLoading {
                LoadingOverlay(serviceName: selectedService.name)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }

            if isMenuExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isMenuExpanded = false
                        }
                    }
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .trailing) {
            FloatingActionMenu(
                services: serviceManager.visibleServices,
                selectedService: $selectedService,
                isExpanded: $isMenuExpanded,
                onNavigate: handleNavigate
            )
            .padding(.trailing, Metric.fabTrailingPadding)
        }
        .navigationBarHidden(true)
        .onAppear {
            validateSelectedService()
        }
        .onChange(of: serviceManager.visibleServices.map(\.id)) { _, _ in
            validateSelectedService()
        }
        .fullScreenCover(item: $activeSheet) { sheet in
            FullScreenPageContainer(sheet: sheet) {
                activeSheet = nil
            }
        }
    }

    // MARK: - Actions
    private func handleNavigate(to target: ActiveSheet) {
        withAnimation(.spring(response: 0.25)) { isMenuExpanded = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            activeSheet = target
        }
    }

    /// 当前服务被禁用/删除时，自动回退到可见服务
    private func validateSelectedService() {
        let visible = serviceManager.visibleServices
        guard !visible.contains(where: { $0.id == selectedService.id }) else { return }
        selectedService = visible.first ?? serviceManager.defaultService
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
        .background(.ultraThinMaterial)
        .onAppear { isAnimating = true }
    }
}
