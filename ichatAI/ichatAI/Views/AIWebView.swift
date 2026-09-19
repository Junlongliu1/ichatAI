// AIWebView.swift
// AI 加载视图 — 完整优化版
// 优化点：
//  1. 实现 WKUIDelegate（target=_blank / window.open / JS 弹窗）
//  2. 加载失败提示 + 错误分类
//  3. 外链 scheme（mailto / tel / 其他 App）交给系统处理
//  4. Blob 大文件保护（JS 端 + Swift 端双重限制）
//  5. WebContent 崩溃重试上限，避免死循环
//  6. WebView 配置补充（inline 播放 / 全屏 / JS 新窗口）
//  7. estimatedProgress KVO 驱动进度条
//  8. 按 reloadToken 支持外部触发重试
//  9. 同步 App 主题到 WebView（仅传递 prefers-color-scheme 信号）

import SwiftUI
import WebKit

// MARK: - WebView 状态
/// 每个 AI 服务独立维护的 WebView 状态
struct WebViewState {
    var isLoading: Bool = true
    var progress: Double = 0
    var error: String?
    /// 外部修改此 token 可以触发一次强制重新加载（用于"重试"）
    var reloadToken: UUID = UUID()
}

// MARK: - AIWebView
struct AIWebView: UIViewRepresentable {
    @Binding var state: WebViewState
    let currentURL: String
    /// 当前 App 的主题样式，用于同步给 WKWebView
    let uiStyle: UIUserInterfaceStyle

    // MARK: UIViewRepresentable
    func makeCoordinator() -> Coordinator {
        Coordinator(state: $state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // 允许内联播放视频（默认 iOS 会强制全屏）
        config.allowsInlineMediaPlayback = true
        // 允许元素进入全屏（视频 / 图片预览）
        config.preferences.isElementFullscreenEnabled = true
        // 允许 JS 用 window.open 打开新窗口（配合 WKUIDelegate）
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        // 允许媒体自动播放（很多 AI 网页需要）
        config.mediaTypesRequiringUserActionForPlayback = []

        config.userContentController.add(
            context.coordinator,
            name: Coordinator.downloadMessageName
        )

        let webView = WKWebView(frame: .zero, configuration: config)

        // 创建时同步主题
        webView.overrideUserInterfaceStyle = uiStyle

        webView.customUserAgent = Self.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        context.coordinator.startObserving(webView)
        context.coordinator.load(
            urlString: currentURL,
            in: webView,
            reloadToken: state.reloadToken
        )
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 主题变化时同步给 WebView，不注入 JS
        if uiView.overrideUserInterfaceStyle != uiStyle {
            uiView.overrideUserInterfaceStyle = uiStyle
        }

        context.coordinator.load(
            urlString: currentURL,
            in: uiView,
            reloadToken: state.reloadToken
        )
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        coordinator.stopObserving()
        uiView.configuration.userContentController
            .removeScriptMessageHandler(forName: Coordinator.downloadMessageName)
    }

    // MARK: - User-Agent（保持最新 Chrome 版本号）
    private static let userAgent: String = {
        let osVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(osVersion) like Mac OS X) "
             + "AppleWebKit/605.1.15 (KHTML, like Gecko) "
             + "CriOS/135.0.7049.83 Mobile/15E148 Safari/604.1"
    }()
}

// MARK: - Coordinator
extension AIWebView {

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

        @Binding var state: WebViewState

        private var currentServiceURL: String = ""
        private var lastReloadToken: UUID?
        private var observation: NSKeyValueObservation?
        private var crashCount = 0

        /// 单个 Blob 允许的最大字节数（Swift 端最终防线）
        private let maxBlobSize: Int64 = 20 * 1024 * 1024 // 20 MB

        static let downloadMessageName = "appDownloadHandler"

        init(state: Binding<WebViewState>) {
            self._state = state
        }

        // MARK: - KVO: estimatedProgress
        func startObserving(_ webView: WKWebView) {
            observation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                let value = webView.estimatedProgress
                DispatchQueue.main.async {
                    self.state.progress = value
                }
            }
        }

        func stopObserving() {
            observation?.invalidate()
            observation = nil
        }

        // MARK: - 统一加载入口
        /// 只在 URL 变化或 reloadToken 变化时才真正 load。
        func load(urlString: String, in webView: WKWebView, reloadToken: UUID) {
            let tokenChanged = (lastReloadToken != nil) && (lastReloadToken != reloadToken)
            let urlChanged = urlString != currentServiceURL

            guard urlChanged || tokenChanged else { return }

            lastReloadToken = reloadToken
            currentServiceURL = urlString

            guard let url = URL(string: urlString) else {
                updateState {
                    $0.isLoading = false
                    $0.error = "无效的网址"
                }
                return
            }

            crashCount = 0
            updateState {
                $0.isLoading = true
                $0.error = nil
                $0.progress = 0
            }
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

        // MARK: - 保存 Blob 到沙盒
        private func saveDataURIToDisk(_ dataUri: String) {
            // 快速拒绝明显过大的 base64（base64 长度 ≈ 原始大小 × 4/3）
            let maxBase64Length = Int(maxBlobSize) * 4 / 3 + 64
            guard dataUri.count <= maxBase64Length else {
                AppLogError("[Blob] 数据过大，已拒绝（base64 长度 \(dataUri.count)，上限 \(maxBase64Length)）")
                return
            }

            let maxSize = self.maxBlobSize

            DispatchQueue.global(qos: .userInitiated).async {
                guard let commaIndex = dataUri.firstIndex(of: ",") else {
                    AppLogError("无效的 Data URI")
                    return
                }

                let meta = String(dataUri[..<commaIndex])
                let base64Raw = String(dataUri[dataUri.index(after: commaIndex)...])
                let base64Str = base64Raw
                    .components(separatedBy: .whitespacesAndNewlines)
                    .first ?? ""

                guard let fileData = Data(base64Encoded: base64Str) else {
                    AppLogError("Base64 解码失败")
                    return
                }

                guard fileData.count <= Int(maxSize) else {
                    AppLogError("文件过大，已拒绝：\(fileData.count / 1024 / 1024)MB")
                    return
                }

                let ext = Self.fileExtension(for: meta)
                let fileName = "doubao_\(Int(Date().timeIntervalSince1970)).\(ext)"
                let fileURL = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(fileName)

                do {
                    try fileData.write(to: fileURL)
                    AppLogInfo("文件已保存到 App 内部: \(fileURL.path)")
                    AppLogInfo("大小: \(fileData.count / 1024)KB | 类型: \(ext)")
                } catch {
                    AppLogError("写入沙盒失败: \(error.localizedDescription)")
                }
            }
        }

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

        // MARK: - WKUIDelegate: target=_blank / window.open
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // targetFrame == nil 表示这是 target=_blank 或 window.open
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        // MARK: - WKUIDelegate: JS alert / confirm / prompt
        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
            topViewController()?.present(alert, animated: true)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
            topViewController()?.present(alert, animated: true)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            topViewController()?.present(alert, animated: true)
        }

        private func topViewController() -> UIViewController? {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }),
                  var top = window.rootViewController else {
                return nil
            }
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }

        // MARK: - WKNavigationDelegate: Policy
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""

            // 非 Web 常用的 scheme（mailto / tel / 其他 App）→ 交给系统
            let allowedSchemes: Set<String> = [
                "http", "https", "blob", "about", "file", "data", "javascript"
            ]
            if !allowedSchemes.contains(scheme) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }

            // Blob 下载：仅在用户主动点击链接时拦截为"下载"
            // （页面内嵌的 blob 图片、视频预览不受影响，仍走正常导航）
            if scheme == "blob" && navigationAction.navigationType == .linkActivated {
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

            let maxSize = self.maxBlobSize

            // JS 端提前拦截超大 Blob，避免把 base64 字符串搬过 bridge
            let js = """
            (function() {
                var xhr = new XMLHttpRequest();
                xhr.open('GET', '\(escaped)', true);
                xhr.responseType = 'blob';
                xhr.onload = function() {
                    var blob = xhr.response;
                    var maxSize = \(maxSize);
                    if (blob && blob.size > maxSize) {
                        console.error('Blob too large: ' + blob.size + ' bytes, limit ' + maxSize);
                        return;
                    }
                    var reader = new FileReader();
                    reader.onloadend = function() {
                        window.webkit.messageHandlers.\(Self.downloadMessageName)
                            .postMessage(reader.result);
                    };
                    reader.readAsDataURL(blob);
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
            updateState {
                $0.isLoading = true
                $0.error = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            crashCount = 0
            updateState {
                $0.isLoading = false
                $0.progress = 1.0
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleError(error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            handleError(error)
        }

        private func handleError(_ error: Error) {
            let nsError = error as NSError

            // NSURLErrorCancelled 是正常取消（例如快速切服务），忽略
            if nsError.code == NSURLErrorCancelled { return }

            let message: String
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                message = "网络未连接，请检查网络设置"
            case NSURLErrorTimedOut:
                message = "连接超时，请稍后重试"
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                message = "无法连接到服务器"
            case NSURLErrorNetworkConnectionLost:
                message = "网络连接已断开"
            default:
                message = "加载失败，请稍后重试"
            }

            AppLogError("[WebView] 加载失败 code=\(nsError.code): \(error.localizedDescription)")
            updateState {
                $0.isLoading = false
                $0.error = message
            }
        }

        /// WebContent 进程被系统回收（内存压力）时自动重载，超过 2 次则停止，避免死循环
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            crashCount += 1
            AppLogError("[WebView] WebContent 进程终止，第 \(crashCount) 次")

            guard crashCount <= 2 else {
                updateState {
                    $0.isLoading = false
                    $0.error = "页面多次崩溃，请稍后重试"
                }
                return
            }

            updateState { $0.isLoading = true }
            webView.reload()
        }

        // MARK: - State helper
        private func updateState(_ transform: @escaping (inout WebViewState) -> Void) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var newState = self.state
                transform(&newState)
                self.state = newState
            }
        }
    }
}
