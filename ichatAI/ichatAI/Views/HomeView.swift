import SwiftUI

struct HomeView: View {
    @StateObject private var serviceManager = AIServiceManager.shared
    @State private var selectedService: AIService
    @State private var isWebLoading = true
    
    init() {
        // 初始化时使用默认服务
        _selectedService = State(initialValue: AIServiceManager.shared.defaultService)
    }
    
    var body: some View {
        ZStack {
            AIWebView(
                isLoading: $isWebLoading,
                currentURL: selectedService.url
            )
            .id(selectedService.id)
            
            if isWebLoading {
                LoadingOverlay(serviceName: selectedService.name)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(false)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Menu {
                    Picker("选择 AI 服务", selection: $selectedService) {
                        ForEach(serviceManager.visibleServices) { service in
                            Text(service.name).tag(service)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedService.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .onAppear {
            // 确保选中项始终在可见列表中
            if !serviceManager.visibleServices.contains(selectedService) {
                selectedService = serviceManager.defaultService
            }
        }
    }
}

//  加载动画覆盖层
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
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
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
