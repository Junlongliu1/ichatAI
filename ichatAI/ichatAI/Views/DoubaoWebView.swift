import SwiftUI
import WebKit

struct DoubaoWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    let currentURL: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        config.userContentController.add(
            context.coordinator,
            name: Coordinator.downloadMessageName
        )
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/131.0.6778.85 Mobile/15E148 Safari/604.1"
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.navigationDelegate = context.coordinator
        
        DispatchQueue.main.async {
            _isLoading.wrappedValue = true
        }
        
        if let url = URL(string: currentURL) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard currentURL != context.coordinator.currentServiceURL else { return }
        
        context.coordinator.currentServiceURL = currentURL
        
        DispatchQueue.main.async {
            _isLoading.wrappedValue = true
        }
        uiView.stopLoading()
        if let url = URL(string: currentURL) {
            uiView.load(URLRequest(url: url))
        }
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController
            .removeScriptMessageHandler(forName: Coordinator.downloadMessageName)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var isLoading: Bool
        var currentServiceURL: String = ""
        
        static let downloadMessageName = "appDownloadHandler"
        
        init(isLoading: Binding<Bool>) {
            self._isLoading = isLoading
        }
        
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == Self.downloadMessageName,
                  let dataUri = message.body as? String else { return }
            saveBlobToAppSandbox(dataUri: dataUri)
        }
        
        private func saveBlobToAppSandbox(dataUri: String) {
            guard let commaIndex = dataUri.firstIndex(of: ",") else {
                AppLog("无效的 Data URI"); return
            }
            
            let meta = String(dataUri[..<commaIndex])
            let base64Str = String(dataUri[dataUri.index(after: commaIndex)...])
                .components(separatedBy: .whitespacesAndNewlines).first ?? ""
            
            guard let fileData = Data(base64Encoded: base64Str) else {
                AppLog("Base64 解码失败"); return
            }
            
            let ext: String
            if meta.contains("image/png") { ext = "png" }
            else if meta.contains("image/jpeg") || meta.contains("image/jpg") { ext = "jpg" }
            else if meta.contains("image/webp") { ext = "webp" }
            else if meta.contains("application/pdf") { ext = "pdf" }
            else if meta.contains("video/mp4") { ext = "mp4" }
            else { ext = "bin" }
            
            let fileName = "doubao_\(Int(Date().timeIntervalSince1970)).\(ext)"
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            
            do {
                try fileData.write(to: fileURL)
                AppLog("文件已保存到 App 内部: \(fileURL.path)")
                AppLog("大小: \(fileData.count / 1024)KB | 类型: \(ext)")
            } catch {
                AppLog("写入沙盒失败: \(error.localizedDescription)")
            }
        }
        
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            if url.scheme == "blob" {
                injectNativeDownloader(webView: webView, blobUrl: url.absoluteString)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
        
        private func injectNativeDownloader(webView: WKWebView, blobUrl: String) {
            let js = """
            (function() {
                var xhr = new XMLHttpRequest();
                xhr.open('GET', '\(blobUrl)', true);
                xhr.responseType = 'blob';
                xhr.onload = function() {
                    var reader = new FileReader();
                    reader.onloadend = function() {
                        window.webkit.messageHandlers.\(Self.downloadMessageName)
                            .postMessage(reader.result);
                    };
                    reader.readAsDataURL(xhr.response);
                };
                xhr.onerror = function() {
                    console.error('Blob download failed');
                };
                xhr.send();
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.isLoading = true }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.isLoading = false }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
}
