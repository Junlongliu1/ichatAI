// ThemeApplier.swift
import UIKit

@MainActor
enum ThemeApplier {

    /// 立即把主题应用到当前所有 Window
    static func apply(_ theme: AppTheme, animated: Bool = true) {
        let style = theme.uiStyle

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                // 直接赋值即可，系统会自动处理颜色过渡，不会闪屏
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
