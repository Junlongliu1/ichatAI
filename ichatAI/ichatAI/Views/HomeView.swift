// HomeView.swift
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
                onNavigate: { target in
                    withAnimation(.spring(response: 0.25)) { isMenuExpanded = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        activeSheet = target
                    }
                }
            )
            .padding(.trailing, 12)
        }
        .navigationBarHidden(true)
        .onAppear {
            if !serviceManager.visibleServices.contains(selectedService) {
                selectedService = serviceManager.defaultService
            }
        }
        .fullScreenCover(item: $activeSheet) { sheet in
            FullScreenPageContainer(sheet: sheet) {
                activeSheet = nil
            }
        }
    }
}

// MARK: - 全屏页面容器
private struct FullScreenPageContainer: View {
    let sheet: HomeView.ActiveSheet
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            switch sheet {
            case .files:
                FilesTabView(onDismiss: onDismiss)
            case .settings:
                SettingsView(onDismiss: onDismiss)
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
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.15), value: isAnimating)
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

// MARK: - 悬浮球 + 展开菜单
private struct FloatingActionMenu: View {
    let services: [AIService]
    @Binding var selectedService: AIService
    @Binding var isExpanded: Bool
    let onNavigate: (HomeView.ActiveSheet) -> Void

    private let buttonSize: CGFloat = 48
    private let menuGap: CGFloat = 10
    private let menuWidth: CGFloat = 200
    private let rowHeight: CGFloat = 38
    private let maxVisibleRows = 5

    private var servicesAreaHeight: CGFloat {
        let rows = max(1, min(services.count, maxVisibleRows))
        return CGFloat(rows) * rowHeight + 12
    }

    var body: some View {
        triggerButton
            .overlay(alignment: .topTrailing) {
                if isExpanded {
                    compactMenuContent
                        .offset(y: buttonSize + menuGap)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85, anchor: .topTrailing)
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.78)),
                            removal: .scale(scale: 0.92, anchor: .topTrailing)
                                .combined(with: .opacity)
                                .animation(.easeOut(duration: 0.15))
                        ))
                }
            }
    }

    // MARK: 悬浮球
    private var triggerButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: buttonSize, height: buttonSize)

                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                    .frame(width: buttonSize, height: buttonSize)

                Text(String(selectedService.name.prefix(1)))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.accentColor.opacity(0.35), radius: 10, y: 4)
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selectedService.id)
    }

    // MARK: 展开面板
    private var compactMenuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── 顶部功能栏 ──
            HStack(spacing: 0) {
                CompactMenuIconButton(icon: "folder.fill", title: "文件") {
                    onNavigate(.files)
                }
                Divider().frame(height: 24).opacity(0.25)
                CompactMenuIconButton(icon: "gearshape.fill", title: "设置") {
                    onNavigate(.settings)
                }
            }
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 12).opacity(0.25)

            // ── AI 服务列表 ──
            ScrollView(.vertical, showsIndicators: services.count > maxVisibleRows) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(services) { service in
                        CompactServiceRow(
                            name: service.name,
                            isSelected: selectedService.id == service.id
                        )
                        .onTapGesture {
                            UISelectionFeedbackGenerator().selectionChanged()
                            selectedService = service
                            withAnimation(.spring(response: 0.3)) { isExpanded = false }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(height: servicesAreaHeight)
        }
        .frame(width: menuWidth)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }
}

// MARK: - 服务行
private struct CompactServiceRow: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isSelected ? Color.white : Color.clear)
                .frame(width: 2.5, height: 12)

            Text(name)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.9) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - 顶部功能按钮
private struct CompactMenuIconButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
