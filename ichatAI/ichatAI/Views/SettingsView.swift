//
//  SettingsView.swift
//  iChatAI
//
//  设置页 —— iOS 26 液态玻璃风格
//

import SwiftUI

// MARK: - 布局常量

private enum SettingsLayout {
    static let cardRadius: CGFloat = 22
    static let cardSpacing: CGFloat = 14
    static let horizontalPadding: CGFloat = 16
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 12
    static let dividerLeading: CGFloat = 54   // 16 + 26 + 12
}

// MARK: - 路由

private enum SettingsRoute: Hashable {
    case aiService
    case logs
    case storage
    case about
}

// MARK: - 主题枚举
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    /// 供 UIWindow.overrideUserInterfaceStyle 使用
    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - 设置界面

struct SettingsView: View {
    let onDismiss: () -> Void

    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @State private var path = NavigationPath()

    private var currentTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }

    // MARK: - Body
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: SettingsLayout.cardSpacing) {
                    appearanceCard
                    aiAndStorageCard
                    developerCard
                    footerNote
                }
                .padding(.horizontal, SettingsLayout.horizontalPadding)
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
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
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

    // MARK: - 外观卡

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "paintpalette.fill",
                iconColor: .pink,
                title: "外观"
            )

            Picker("主题", selection: $appThemeRaw) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName)
                        .tag(theme.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
            .padding(.bottom, 12)
            .onChange(of: appThemeRaw) { _, newValue in
                UISelectionFeedbackGenerator().selectionChanged()
                AppLogInfo("[Settings] 主题切换为 \(newValue)")
            }

            Text("选择「跟随系统」将自动匹配设备深色模式。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: SettingsLayout.cardRadius))
    }

    private func themeOption(_ theme: AppTheme) -> some View {
        let isSelected = appThemeRaw == theme.rawValue
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            appThemeRaw = theme.rawValue
        } label: {
            VStack(spacing: 8) {
                Image(systemName: theme.icon)
                    .font(.system(size: 22, weight: .medium))
                    .symbolRenderingMode(.hierarchical)

                Text(theme.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.14)
                          : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.5) : .clear,
                        lineWidth: 1.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isSelected)
    }

    // MARK: - AI 和存储管理卡
    private var aiAndStorageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "sparkles",
                iconColor: .purple,
                title: "AI和存储管理"
            )

            // AI 服务管理
            Button {
                path.append(SettingsRoute.aiService)
            } label: {
                SettingsRow(
                    title: "服务管理",
                    subtitle: "管理内置与自定义服务",
                    badge: nil
                )
            }
            .buttonStyle(GlassRowButtonStyle())

            SettingsRowDivider()

            // 存储管理
            Button {
                path.append(SettingsRoute.storage)
            } label: {
                SettingsRow(
                    title: "存储管理",
                    subtitle: "扫描并清理 WebKit 缓存",
                    badge: nil
                )
            }
            .buttonStyle(GlassRowButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: SettingsLayout.cardRadius))
    }

    // MARK: - 开发者卡（仅保留日志与关于）
    private var developerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "hammer.fill",
                iconColor: .orange,
                title: "开发者"
            )

            // 调试日志
            Button {
                path.append(SettingsRoute.logs)
            } label: {
                SettingsRow(
                    title: "调试日志",
                    subtitle: "查看应用运行日志",
                    badge: nil
                )
            }
            .buttonStyle(GlassRowButtonStyle())

            SettingsRowDivider()

            // 关于 iChatAI
            Button {
                path.append(SettingsRoute.about)
            } label: {
                SettingsRow(
                    title: "关于 iChatAI",
                    subtitle: "版本、开发者与更多信息",
                    badge: nil
                )
            }
            .buttonStyle(GlassRowButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: SettingsLayout.cardRadius))
    }

    // MARK: - Footer

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

// MARK: - 卡片标题

struct SettingsCardHeader: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Spacer()
        }
        .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

// MARK: - 行分隔线

struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.05))
            .frame(height: 0.5)
            .padding(.leading, SettingsLayout.dividerLeading)
            .padding(.trailing, 16)
    }
}

// MARK: - 通用设置行

struct SettingsRow: View {
    var icon: String? = nil
    var iconColor: Color = .gray
    let title: String
    let subtitle: String
    let badge: String?
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        iconColor.gradient,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)
                    .font(.system(size: 15, weight: .medium))

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let badge {
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule().fill(Color.secondary.opacity(0.10))
                    )
                    .transition(.scale.combined(with: .opacity))
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
        .contentShape(Rectangle())
    }
}

// MARK: - 信息行

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }
}

// MARK: - 行按下反馈

struct GlassRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.06) : .clear)
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
