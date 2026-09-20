// ichatAIApp.swift
import SwiftUI

@main
struct ichatAIApp: App {
    init() {
        // 应用启动前同步一次，避免闪屏
        let theme = ThemeManager.shared.current
        ThemeManager.shared.apply(animated: false)
        AppLogInfo("[App] 启动，主题: \(theme.displayName)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // 注册场景监听
                    ThemeManager.shared.startObservingScenes()
                }
        }
    }
}
