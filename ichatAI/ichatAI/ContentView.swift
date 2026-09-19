//  ContentView.swift

import SwiftUI

struct ContentView: View {
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .onAppear {
            // 首次展示也同步一次（和 App.init 保持一致）
            applyTheme(animated: false)
        }
        .onChange(of: appThemeRaw) { _, _ in
            // 修复闪烁：延迟到下一帧执行，避免与 SwiftUI 的视图更新冲突
            DispatchQueue.main.async {
                applyTheme(animated: true)
            }
        }
    }

    private func applyTheme(animated: Bool) {
        let theme = AppTheme(rawValue: appThemeRaw) ?? .system
        ThemeApplier.apply(theme, animated: animated)
    }
}
