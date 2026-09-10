// AIWebView.swift
// AI 加载视图
import SwiftUI
import WebKit

struct AIWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    let currentURL: String

    // MARK: - UIViewRepresentable
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
        webView.customUserAgent = Self.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.navigationDelegate = context.coordinator

        // 走统一入口：同时初始化 currentServiceURL，避免 updateUIView 重复加载
        context.coordinator.load(urlString: currentURL, in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 内部判断 URL 是否变化，无变化直接返回
        context.coordinator.load(urlString: currentURL, in: uiView)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        uiView.configuration.userContentController
            .removeScriptMessageHandler(forName: Coordinator.downloadMessageName)
    }

    // MARK: - User-Agent（系统版本动态化）
    private static let userAgent: String = {
        let osVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(osVersion) like Mac OS X) "
             + "AppleWebKit/605.1.15 (KHTML, like Gecko) "
             + "CriOS/131.0.6778.85 Mobile/15E148 Safari/604.1"
    }()
}

// MARK: - Coordinator
extension AIWebView {

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var isLoading: Bool
        private var currentServiceURL: String = ""

        static let downloadMessageName = "appDownloadHandler"

        init(isLoading: Binding<Bool>) {
            self._isLoading = isLoading
        }

        // MARK: - 统一加载入口
        /// 只在 URL 变化时才真正 load。解决 makeUIView → updateUIView 连续触发的重复加载。
        func load(urlString: String, in webView: WKWebView) {
            guard urlString != currentServiceURL else { return }
            currentServiceURL = urlString

            guard let url = URL(string: urlString) else { return }
            setLoading(true)
            webView.stopLoading()
            webView.load(URLRequest(url: url))
        }

        // MARK: - WKScriptMessageHandler
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == Self.downloadMessageName,
                  let dataUri = message.body as? String else { return }
            saveDataURIToDisk(dataUri)
        }

        // MARK: - 保存到沙盒（异步 IO，不卡主线程）
        private func saveDataURIToDisk(_ dataUri: String) {
            DispatchQueue.global(qos: .userInitiated).async {
                guard let commaIndex = dataUri.firstIndex(of: ",") else {
                    AppLog("无效的 Data URI")
                    return
                }

                let meta = String(dataUri[..<commaIndex])
                let base64Raw = String(dataUri[dataUri.index(after: commaIndex)...])
                let base64Str = base64Raw
                    .components(separatedBy: .whitespacesAndNewlines)
                    .first ?? ""

                guard let fileData = Data(base64Encoded: base64Str) else {
                    AppLog("Base64 解码失败")
                    return
                }

                let ext = Self.fileExtension(for: meta)
                let fileName = "doubao_\(Int(Date().timeIntervalSince1970)).\(ext)"
                let fileURL = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(fileName)

                do {
                    try fileData.write(to: fileURL)
                    AppLog("文件已保存到 App 内部: \(fileURL.path)")
                    AppLog("大小: \(fileData.count / 1024)KB | 类型: \(ext)")
                } catch {
                    AppLog("写入沙盒失败: \(error.localizedDescription)")
                }
            }
        }

        /// MIME → 扩展名映射（可读性优于长 if/else）
        private static func fileExtension(for meta: String) -> String {
            let mimeMap: [(String, String)] = [
                ("image/png",       "png"),
                ("image/jpeg",      "jpg"),
                ("image/jpg",       "jpg"),
                ("image/webp",      "webp"),
                ("application/pdf", "pdf"),
                ("video/mp4",       "mp4"),
            ]
            for (mime, ext) in mimeMap where meta.contains(mime) {
                return ext
            }
            return "bin"
        }

        // MARK: - WKNavigationDelegate: Blob 拦截
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
            // 转义，避免 URL 里的单引号/反斜杠破坏 JS 语法
            let escaped = blobUrl
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")

            let js = """
            (function() {
                var xhr = new XMLHttpRequest();
                xhr.open('GET', '\(escaped)', true);
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

        // MARK: - WKNavigationDelegate: Loading 状态
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            setLoading(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            setLoading(false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            setLoading(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            setLoading(false)
        }

        ///  Web Content 进程被系统回收（内存压力）时，自动重载，避免白屏
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            AppLog("WebContent 进程终止，尝试重新加载")
            setLoading(true)
            webView.reload()
        }

        // MARK: - Loading helper
        private func setLoading(_ value: Bool) {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = value
            }
        }
    }
}
