// HomeView.swift
// 首页主视图 — iOS 26+ Liquid Glass 设计
import SwiftUI

struct HomeView: View {
    @StateObject private var serviceManager = AIServiceManager.shared
    @State private var selectedService: AIService
    @State private var isWebLoading = true
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
        .fullScreenCover(item: $activeSheet) { sheet in
            FullScreenPageContainer(sheet: sheet) {
                activeSheet = nil
            }
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
