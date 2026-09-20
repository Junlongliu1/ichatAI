// AIWebView.swift
// AI 加载视图 — 完整优化版
import SwiftUI
import WebKit

// MARK: - 下载通知
extension Notification.Name {
    /// WebView 保存文件成功后广播，供文件页刷新
    static let downloadedFileAdded = Notification.Name("ichatAI.downloadedFileAdded")
}

// MARK: - WebView 状态
struct WebViewState {
    var isLoading: Bool = true
    var progress: Double = 0
    var error: String?
    var reloadToken: UUID = UUID()
}

// MARK: - AIWebView
struct AIWebView: UIViewRepresentable {
    @Binding var state: WebViewState
    let currentURL: String
    let uiStyle: UIUserInterfaceStyle
    /// 当前 WebView 是否为屏幕上正在显示的活跃视图
    let isActive: Bool

    // MARK: UIViewRepresentable
    func makeCoordinator() -> Coordinator {
        Coordinator(state: $state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.isElementFullscreenEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        // 音频需要用户手势才能播放，避免 AI 网页自动播放语音打扰用户
        config.mediaTypesRequiringUserActionForPlayback = [.audio]

        config.userContentController.add(
            context.coordinator,
            name: Coordinator.downloadMessageName
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.overrideUserInterfaceStyle = uiStyle
        webView.isInspectable = Self.isInspectable
        webView.customUserAgent = Self.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        context.coordinator.isActive = isActive
        if !isActive {
            webView.setAllMediaPlaybackSuspended(true, completionHandler: nil)
        }

        context.coordinator.startObserving(webView)
        context.coordinator.load(
            urlString: currentURL,
            in: webView,
            reloadToken: state.reloadToken
        )
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.overrideUserInterfaceStyle != uiStyle {
            uiView.overrideUserInterfaceStyle = uiStyle
        }

        // 非活跃时暂停媒体播放，活跃时恢复
        if context.coordinator.isActive != isActive {
            context.coordinator.isActive = isActive
            uiView.setAllMediaPlaybackSuspended(!isActive, completionHandler: nil)
        }

        context.coordinator.load(
            urlString: currentURL,
            in: uiView,
            reloadToken: state.reloadToken
        )
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        uiView.setAllMediaPlaybackSuspended(true, completionHandler: nil)
        coordinator.stopObserving()
        uiView.configuration.userContentController
            .removeScriptMessageHandler(forName: Coordinator.downloadMessageName)
    }

    // MARK: - Debug / Release 区分：仅 Debug 允许 Safari 检查
    private static let isInspectable: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    // MARK: - User-Agent
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

        /// 由 updateUIView 维护
        var isActive: Bool = true

        private var currentServiceURL: String = ""
        private var lastReloadToken: UUID?
        private var crashCount = 0

        // 观察者
        private var observation: NSKeyValueObservation?
        private var bgObserver: NSObjectProtocol?
        private var fgObserver: NSObjectProtocol?

        /// 单个 Blob 允许的最大字节数（Swift 端最终防线）
        private let maxBlobSize: Int64 = 20 * 1024 * 1024 // 20 MB

        static let downloadMessageName = "appDownloadHandler"

        init(state: Binding<WebViewState>) {
            self._state = state
        }

        // MARK: - KVO + 前后台
        func startObserving(_ webView: WKWebView) {
            observation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                let value = webView.estimatedProgress
                DispatchQueue.main.async {
                    // 节流，避免频繁触发 SwiftUI 更新
                    let old = self.state.progress
                    if abs(old - value) > 0.01 || value >= 1.0 {
                        self.state.progress = value
                    }
                }
            }

            bgObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil, queue: .main
            ) { [weak webView] _ in
                webView?.setAllMediaPlaybackSuspended(true, completionHandler: nil)
            }

            fgObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil, queue: .main
            ) { [weak self, weak webView] _ in
                guard let self, let webView else { return }
                webView.setAllMediaPlaybackSuspended(!self.isActive, completionHandler: nil)
            }
        }

        func stopObserving() {
            observation?.invalidate()
            observation = nil

            if let bgObserver { NotificationCenter.default.removeObserver(bgObserver) }
            if let fgObserver { NotificationCenter.default.removeObserver(fgObserver) }
            bgObserver = nil
            fgObserver = nil
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
        // 支持字符串（旧格式）与字典（带文件名/类型）两种载荷
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == Self.downloadMessageName else { return }

            var dataUri: String?
            var originalName: String?
            var mimeType: String?

            if let dict = message.body as? [String: Any] {
                dataUri      = dict["dataURI"]  as? String
                originalName = dict["fileName"] as? String
                mimeType     = dict["mimeType"] as? String
            } else if let str = message.body as? String {
                dataUri = str
            }

            guard let uri = dataUri else {
                AppLogError("[Blob] 未收到 dataURI")
                return
            }

            saveDataURIToDisk(uri, originalName: originalName, mimeType: mimeType)
        }

        // MARK: - 保存 Blob 到沙盒
        private func saveDataURIToDisk(_ dataUri: String,
                                       originalName: String?,
                                       mimeType: String?) {
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

                // 优先用 mimeType，其次 meta
                let ext = Self.fileExtension(for: mimeType ?? meta)

                // 统一前缀 ai_，并尽量保留原始文件名
                let timestamp = Int(Date().timeIntervalSince1970)
                let baseName: String
                if let originalName, !originalName.isEmpty {
                    let trimmed = (originalName as NSString).deletingPathExtension
                    baseName = Self.sanitize(trimmed)
                } else {
                    baseName = "\(timestamp)"
                }
                let fileName = "ai_\(timestamp)_\(baseName).\(ext)"

                let fileURL = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(fileName)

                do {
                    try fileData.write(to: fileURL)
                    // 文件保护
                    try? FileManager.default.setAttributes(
                        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                        ofItemAtPath: fileURL.path
                    )
                    AppLogInfo("文件已保存: \(fileURL.lastPathComponent) (\(fileData.count / 1024)KB)")

                    // 通知文件页刷新 + Toast 提示
                    Task { @MainActor in
                        NotificationCenter.default.post(
                            name: .downloadedFileAdded,
                            object: nil
                        )
                        ToastCenter.shared.show("已保存到文件")
                    }
                } catch {
                    AppLogError("写入沙盒失败: \(error.localizedDescription)")
                }
            }
        }

        private static func sanitize(_ name: String) -> String {
            let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
            let cleaned = name
                .components(separatedBy: invalid)
                .joined(separator: "_")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? "file" : cleaned
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

            // Blob 下载：仅在用户主动点击链接时拦截为“下载”
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

            // 载荷改为字典，带上 mimeType（文件名一般拿不到，由 Swift 端生成）
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
                            .postMessage({
                                dataURI: reader.result,
                                fileName: null,
                                mimeType: blob.type || ''
                            });
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
