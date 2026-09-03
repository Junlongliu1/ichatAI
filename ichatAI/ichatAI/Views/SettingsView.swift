//  设置页面

import SwiftUI

//  深色模式枚举
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }
}

struct SettingsView: View {
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    
    var body: some View {
        List {
            appearanceSection
            aiServiceSection
            developerSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
    }
    
    // 拆分子视图
    // 外观
    private var appearanceSection: some View {
        Section("外观") {
            Picker(selection: $appThemeRaw) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName)
                        .tag(theme.rawValue)
                }
            } label: {
                Label("显示模式", systemImage: "paintbrush.fill")
            }
        }
    }
    
    //  AI 服务
    private var aiServiceSection: some View {
        Section("AI 服务") {
            NavigationLink(destination: AIServiceManageView()) {
                Label("AI 服务管理", systemImage: "brain.head.profile")
            }
        }
    }
    
    //  开发者
    private var developerSection: some View {
        Section("开发者") {
            NavigationLink(destination: LogViewerView()) {
                Label("调试日志", systemImage: "terminal.fill")
            }
            NavigationLink(destination: StorageManagerView()) {
                Label("存储管理", systemImage: "internaldrive.fill")
            }
        }
    }
    
    //  关于
    private var aboutSection: some View {
        Section("关于 iChatAI") {
            HStack {
                Text("版本号")
                Spacer()
                Text(AppInfo.version)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
