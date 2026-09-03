import SwiftUI
import WebKit

struct DoubaoWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    let proxy: WebViewProxy
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, canGoBack: $canGoBack)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1"
        
        config.userContentController.add(
            context.coordinator,
            name: Coordinator.downloadMessageName
        )
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.navigationDelegate = context.coordinator
        
        webView.addObserver(
            context.coordinator,
            forKeyPath: #keyPath(WKWebView.canGoBack),
            options: [.new],
            context: nil
        )
        
        proxy.webView = webView
        
        DispatchQueue.main.async {
            _isLoading.wrappedValue = true
        }
        
        if let url = URL(string: "https://www.doubao.com/chat/") {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.canGoBack))
        uiView.configuration.userContentController
            .removeScriptMessageHandler(forName: Coordinator.downloadMessageName)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var isLoading: Bool
        @Binding var canGoBack: Bool
        private var hasLoadedInitialPage = false
        
        static let downloadMessageName = "appDownloadHandler"
        
        init(isLoading: Binding<Bool>, canGoBack: Binding<Bool>) {
            self._isLoading = isLoading
            self._canGoBack = canGoBack
        }
        
        // ✅ 接收 JS 传来的 Blob Data URI，写入 App 沙盒
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == Self.downloadMessageName,
                  let dataUri = message.body as? String else { return }
            
            saveBlobToAppSandbox(dataUri: dataUri)
        }
        
        private func saveBlobToAppSandbox(dataUri: String) {
            // 解析 MIME type 和 Base64 数据
            guard let commaIndex = dataUri.firstIndex(of: ",") else {
                print("⚠️ 无效的 Data URI"); return
            }
            
            let meta = String(dataUri[..<commaIndex])
            let base64Str = String(dataUri[dataUri.index(after: commaIndex)...])
                .components(separatedBy: .whitespacesAndNewlines).first ?? ""
            
            guard let fileData = Data(base64Encoded: base64Str) else {
                print("⚠️ Base64 解码失败"); return
            }
            
            // 根据 MIME type 生成文件名和后缀
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
                print("✅ 文件已保存到 App 内部: \(fileURL.path)")
                print("   大小: \(fileData.count / 1024)KB | 类型: \(ext)")
                
                // 💡 后续可在此处触发：
                // - 图片：UIImageWriteToSavedPhotosAlbum / 自定义相册管理器
                // - PDF/视频：UIDocumentInteractionController 预览/分享
                // - 通用：展示下载成功 Toast / 更新本地文件列表
            } catch {
                print("⚠️ 写入沙盒失败: \(error.localizedDescription)")
            }
        }
        
        // ✅ decidePolicyFor：拦截 blob 并注入原生下载 JS
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }
            
            if url.scheme == "blob" {
                injectNativeDownloader(webView: webView, blobUrl: url.absoluteString)
                decisionHandler(.cancel)
                return
            }
            
            if !hasLoadedInitialPage {
                hasLoadedInitialPage = true
                decisionHandler(.allow); return
            }
            
            if let host = url.host, host.contains("doubao.com") {
                decisionHandler(.allow); return
            }
            
            UIApplication.shared.open(url) { success in
                if !success { print("⚠️ 无法打开外部链接: \(url)") }
            }
            decisionHandler(.cancel)
        }
        
        // ✅ 注入 JS：通过 XHR 读取 blob → postMessage 发送给原生
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
        
        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            if keyPath == #keyPath(WKWebView.canGoBack),
               let webView = object as? WKWebView {
                DispatchQueue.main.async {
                    self.canGoBack = webView.canGoBack
                }
            } else {
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.isLoading = true }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = false
                self.canGoBack = webView.canGoBack
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
