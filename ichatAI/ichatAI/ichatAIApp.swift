//  ichatAIApp.swift

import SwiftUI

@main
struct ichatAIApp: App {

    init() {
        // 启动时同步应用一次，避免从系统主题切到用户主题时出现闪烁
        let raw = UserDefaults.standard.string(forKey: "appTheme")
            ?? AppTheme.system.rawValue
        let theme = AppTheme(rawValue: raw) ?? .system
        ThemeApplier.apply(theme, animated: false)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
