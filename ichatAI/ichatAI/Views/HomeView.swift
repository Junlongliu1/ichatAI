// HomeView.swift
import SwiftUI

struct HomeView: View {
    @StateObject private var serviceManager = AIServiceManager.shared
    @State private var selectedService: AIService
    @State private var isWebLoading = true
    
    init() {
        _selectedService = State(initialValue: AIServiceManager.shared.defaultService)
    }
    
    var body: some View {
        ZStack {
            // WebView 主体
            AIWebView(
                isLoading: $isWebLoading,
                currentURL: selectedService.url
            )
            .id(selectedService.id)
            
            // 加载动画
            if isWebLoading {
                LoadingOverlay(serviceName: selectedService.name)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
            
            // ✅ 左上角悬浮菜单按钮
            FloatingActionMenu(
                services: serviceManager.visibleServices,
                selectedService: $selectedService
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        .onAppear {
            if !serviceManager.visibleServices.contains(selectedService) {
                selectedService = serviceManager.defaultService
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

// MARK: - 左上角悬浮菜单组件
private struct FloatingActionMenu: View {
    let services: [AIService]
    @Binding var selectedService: AIService
    @State private var isExpanded = false
    @Environment(\.dismiss) private var dismiss // 用于安全关闭
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // ✅ 修复1: 背景遮罩独立为一层，使用 allowsHitTesting 控制
            if isExpanded {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // 菜单主体
            VStack(alignment: .leading, spacing: 12) {
                if isExpanded {
                    menuContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                
                triggerButton
            }
            .padding(.top, 8)
            .padding(.leading, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // ✅ 修复2: 确保整个 ZStack 不会意外拦截非菜单区域的点击
        .allowsHitTesting(true)
    }
    
    // 触发按钮
    private var triggerButton: some View {
        Button {
            withAnimation(.spring(response: 0.35)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: isExpanded ? "xmark" : "line.3.horizontal")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThickMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .zIndex(1) // ✅ 确保按钮始终在最上层
    }
    
    // 菜单内容面板
    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // AI 服务选择区
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(services) { service in
                        ServiceChip(
                            name: service.name,
                            isSelected: selectedService.id == service.id
                        )
                        .onTapGesture {
                            selectedService = service
                            withAnimation(.spring(response: 0.3)) {
                                isExpanded = false
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider().padding(.horizontal, 16)
            
            // ✅ 修复3: 功能入口改用 Button + NavigationPath 或直接 push
            VStack(spacing: 0) {
                MenuRow(icon: "folder.fill", title: "我的文件") {
                    FilesTabView()
                }
                MenuRow(icon: "gearshape.fill", title: "设置") {
                    SettingsView()
                }
            }
            .padding(.vertical, 4)
        }
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .zIndex(1) // ✅ 确保菜单内容也在遮罩之上
    }
}

// AI 服务选择标签
private struct ServiceChip: View {
    let name: String
    let isSelected: Bool
    
    var body: some View {
        Text(name)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            )
    }
}

// ✅ 修复4: 重构 MenuRow，使用泛型 Destination 但通过 @ViewBuilder 传递
private struct MenuRow<Destination: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let destination: () -> Destination
    
    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle()) // ✅ 确保整行都可点击
        }
        .buttonStyle(.plain)
    }
}
