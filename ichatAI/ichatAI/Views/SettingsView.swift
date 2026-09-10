// SettingsView.swift
// 设置页面
import SwiftUI

// MARK: - 主题枚举
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色模式"
        case .dark:   return "深色模式"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    /// 供 `.preferredColorScheme()` 使用
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    let onDismiss: () -> Void

    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue

    private var currentTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }

    var body: some View {
        List {
            appearanceSection
            aiServiceSection
            developerSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onDismiss) {
                    Label("返回", systemImage: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 外观
    private var appearanceSection: some View {
        Section("外观") {
            Picker(selection: $appThemeRaw) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.displayName, systemImage: theme.icon)
                        .tag(theme.rawValue)
                }
            } label: {
                Text("显示模式")
            }
        }
    }

    // MARK: - AI 服务
    private var aiServiceSection: some View {
        Section("AI 服务") {
            NavigationLink {
                AIServiceManageView()
            } label: {
                Text("AI 服务管理")
            }
        }
    }

    // MARK: - 开发者
    private var developerSection: some View {
        Section("开发者") {
            NavigationLink {
                LogViewerView()
            } label: {
                Text("调试日志")
            }
            NavigationLink {
                StorageManagerView()
            } label: {
                Text("存储管理")
            }
        }
    }

    // MARK: - 关于
    private var aboutSection: some View {
        Section("关于") {
            LabeledContent("应用名称", value: "iChatAI")
            LabeledContent("版本号", value: AppInfo.version)
        }
    }
}
