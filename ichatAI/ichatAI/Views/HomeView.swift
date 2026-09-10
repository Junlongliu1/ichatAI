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

            VStack {
                Spacer()
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
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 12)
            .ignoresSafeArea(edges: [.top, .bottom])
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

// MARK: - 紧凑型贴边下拉悬浮菜单（排版修复版）
private struct FloatingActionMenu: View {
    let services: [AIService]
    @Binding var selectedService: AIService
    @Binding var isExpanded: Bool
    let onNavigate: (HomeView.ActiveSheet) -> Void
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            triggerButton
            
            if isExpanded {
                compactMenuContent
                    .padding(.top, 6)
                    // ✅ 关键修复：强制整个菜单面板以右上角为基准对齐
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .topTrailing)
                            .combined(with: .opacity)
                            .animation(.spring(response: 0.4, dampingFraction: 0.75)),
                        removal: .scale(scale: 0.95, anchor: .topTrailing)
                            .combined(with: .opacity)
                            .animation(.spring(response: 0.2, dampingFraction: 0.9))
                    ))
            }
        }
        // ✅ 确保外层 VStack 不会撑满父容器高度
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private var triggerButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            Text(String(selectedService.name.prefix(1)))
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private var compactMenuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                CompactMenuIconButton(icon: "folder.fill", title: "文件") {
                    onNavigate(.files)
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 18).opacity(0.3)
                
                CompactMenuIconButton(icon: "gearshape.fill", title: "设置") {
                    onNavigate(.settings)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 6)
            
            Divider().padding(.horizontal, 8).opacity(0.3)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(services) { service in
                        CompactServiceRow(
                            name: service.name,
                            isSelected: selectedService.id == service.id
                        )
                        .onTapGesture {
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                            selectedService = service
                            withAnimation(.spring(response: 0.3)) { isExpanded = false }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            // ✅ 移除固定 maxHeight，改为自适应内容高度，避免空白撑开
            .frame(maxHeight: 220, alignment: .top)
        }
        .frame(width: 180, alignment: .topLeading) // ✅ 强制内容左上角对齐
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
    }
}

// MARK: - 紧凑版子组件
private struct CompactServiceRow: View {
    let name: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1)
                .fill(isSelected ? Color.white : Color.clear)
                .frame(width: 2, height: 12)
            
            Text(name)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .foregroundStyle(isSelected ? Color.accentColor.opacity(0.9) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

private struct CompactMenuIconButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}
