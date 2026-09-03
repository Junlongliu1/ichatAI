import SwiftUI

struct HomeView: View {
    @State private var isWebLoading = true
    @State private var selectedService: AIService = .doubao
    @State private var showServicePicker = false
    
    var body: some View {
        ZStack {
            DoubaoWebView(
                isLoading: $isWebLoading,
                currentURL: selectedService.url
            )
            .id(selectedService)
            
            if isWebLoading {
                LoadingOverlay(serviceName: selectedService.rawValue)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(false)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showServicePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedService.icon)
                            .foregroundStyle(selectedService.color)
                        Text(selectedService.rawValue)
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
        .confirmationDialog(
            "选择 AI 服务",
            isPresented: $showServicePicker,
            titleVisibility: .visible
        ) {
            ForEach(AIService.allCases) { service in
                Button {
                    if service != selectedService {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedService = service
                        }
                    }
                } label: {
                    Label(service.rawValue, systemImage: service.icon)
                }
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
