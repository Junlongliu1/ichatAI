// SettingsView.swift
import SwiftUI

private enum SettingsRoute: Hashable {
    case aiService
    case logs
    case storage
    case about
}

struct SettingsView: View {
    let onDismiss: () -> Void

    private let themeManager = ThemeManager.shared
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: DSLayout.cardSpacing) {
                    appearanceCard
                    aiAndStorageCard
                    developerCard
                    footerNote
                }
                .padding(.horizontal, DSLayout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("返回")
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .aiService: AIServiceManageView()
                case .logs:      LogViewerView()
                case .storage:   StorageManagerView()
                case .about:     AboutView()
                }
            }
        }
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(icon: "paintpalette.fill", iconColor: .pink, title: "外观")

            Picker("主题", selection: Binding(
                get: { themeManager.current },
                set: { themeManager.setTheme($0) }
            )) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DSLayout.rowHorizontalPadding)
            .padding(.bottom, 12)
            .onChange(of: themeManager.current) { _, _ in
                UISelectionFeedbackGenerator().selectionChanged()
            }

            Text("选择「跟随系统」将自动匹配设备深色模式。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DSLayout.rowHorizontalPadding)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: DSLayout.cardRadius))
    }

    private var aiAndStorageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(icon: "sparkles", iconColor: .purple, title: "AI和存储管理")

            Button { path.append(SettingsRoute.aiService) } label: {
                SettingsRow(title: "服务管理", subtitle: "管理内置与自定义服务", badge: nil)
            }
            .buttonStyle(GlassRowButtonStyle())

            SettingsRowDivider()

            Button { path.append(SettingsRoute.storage) } label: {
                SettingsRow(title: "存储管理", subtitle: "扫描并清理 WebKit 缓存", badge: nil)
            }
            .buttonStyle(GlassRowButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: DSLayout.cardRadius))
    }

    private var developerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(icon: "hammer.fill", iconColor: .orange, title: "开发者")

            Button { path.append(SettingsRoute.logs) } label: {
                SettingsRow(title: "调试日志", subtitle: "查看应用运行日志", badge: nil)
            }
            .buttonStyle(GlassRowButtonStyle())

            SettingsRowDivider()

            Button { path.append(SettingsRoute.about) } label: {
                SettingsRow(title: "关于 iChatAI", subtitle: "版本、开发者与更多信息", badge: nil)
            }
            .buttonStyle(GlassRowButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: DSLayout.cardRadius))
    }

    private var footerNote: some View {
        Text("iChatAI 是一个轻量的 AI 网页聚合工具，数据与登录态均保存在本机，不会上传到任何服务器。")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 4)
    }
}
