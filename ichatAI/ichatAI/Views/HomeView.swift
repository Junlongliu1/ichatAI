import SwiftUI
import WebKit

struct HomeView: View {
    @State private var isWebLoading = true
    @State private var canGoBack = false
    @State private var webViewProxy = WebViewProxy()
    
    var body: some View {
        ZStack {
            DoubaoWebView(
                isLoading: $isWebLoading,
                canGoBack: $canGoBack,
                proxy: webViewProxy
            )
            
            if isWebLoading {
                LoadingOverlay()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(false)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    webViewProxy.goBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("返回")
                    }
                }
                .disabled(!canGoBack)
                .opacity(canGoBack ? 1 : 0)
            }
        }
    }
}

// MARK: - WebView Proxy (用于从 SwiftUI 调用 UIKit 方法)
class WebViewProxy {
    weak var webView: WKWebView?
    
    func goBack() {
        guard let webView, webView.canGoBack else { return }
        webView.goBack()
    }
}

// MARK: - 加载动画覆盖层
private struct LoadingOverlay: View {
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
            
            Text("正在加载豆包...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { isAnimating = true }
    }
}
