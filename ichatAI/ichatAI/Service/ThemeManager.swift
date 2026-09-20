// ThemeManager.swift
import SwiftUI
import UIKit
import Observation

@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    static let storageKey = "appTheme"

    private(set) var current: AppTheme

    @ObservationIgnored
    private var sceneObserver: NSObjectProtocol?

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppTheme.system.rawValue
        self.current = AppTheme(rawValue: raw) ?? .system
    }

    /// App 启动后调用一次：注册场景监听（新窗口继承主题）
    func startObservingScenes() {
        guard sceneObserver == nil else { return }
        sceneObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ThemeManager.shared.apply(animated: false)
            }
        }
    }

    func setTheme(_ theme: AppTheme) {
        guard theme != current else { return }
        current = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
        AppLogInfo("[Theme] 切换为 \(theme.displayName)")
        apply(animated: true)
    }

    /// 立即应用到所有窗口
    func apply(animated: Bool) {
        let style = current.uiStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
