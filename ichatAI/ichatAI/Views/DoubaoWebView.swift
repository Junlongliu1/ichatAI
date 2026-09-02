import SwiftUI
import WebKit

struct DoubaoWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // 模拟移动端 Safari UA，确保加载移动版页面
        config.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1"
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        
        // 加载豆包网页版
        if let url = URL(string: "https://www.doubao.com/chat/") {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
