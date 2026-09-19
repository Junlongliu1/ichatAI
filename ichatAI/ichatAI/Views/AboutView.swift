//
//  AboutView.swift
//  iChatAI
//
//  关于页 —— iOS 26 液态玻璃风格
//

import SwiftUI

// MARK: - 关于界面

struct AboutView: View {

    // MARK: - 布局常量
    private enum Layout {
        static let cardRadius: CGFloat = 22
        static let cardSpacing: CGFloat = 14
        static let horizontalPadding: CGFloat = 16
        static let rowHorizontalPadding: CGFloat = 16
    }

    // MARK: - 版本信息
    private var appVersion: String {
        guard let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            AppLogWarn("[About] CFBundleShortVersionString 缺失，使用默认值 1.0")
            return "1.0"
        }
        return v
    }

    private var buildNumber: String {
        guard let v = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            AppLogWarn("[About] CFBundleVersion 缺失，使用默认值 1")
            return "1"
        }
        return v
    }

    private var copyright: String {
        let year = Calendar.current.component(.year, from: Date())
        return "© \(year) iChatAI Team"
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Layout.cardSpacing) {
                heroCard
                introCard
                infoCard
                copyrightNote
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.49, blue: 0.95),   // 蓝色
                            Color(red: 0.35, green: 0.28, blue: 0.88)    // 紫色
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.white)
                )
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)

            VStack(spacing: 4) {
                Text("iChatAI")
                    .font(.title2.bold())

                Text("版本 \(appVersion) (\(buildNumber))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .glassEffect(.regular, in: .rect(cornerRadius: Layout.cardRadius))
    }

    // MARK: - 简介

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(icon: "text.alignleft", iconColor: .blue, title: "简介")

            Text("iChatAI 是一个轻量的 AI 网页聚合工具，数据与登录态均保存在本机，不会上传到任何服务器。支持豆包、文心一言、通义千问、Kimi、DeepSeek 等主流 AI 服务，并允许添加自定义服务。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.rowHorizontalPadding)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Layout.cardRadius))
    }

    // MARK: - 信息

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(icon: "info.circle", iconColor: .blue, title: "信息")

            AboutInfoRow(label: "版本",   value: appVersion)
            infoDivider
            AboutInfoRow(label: "构建号", value: buildNumber)
            infoDivider
            AboutInfoRow(label: "最低系统", value: "iOS 26.0")
            infoDivider
            AboutInfoRow(label: "开发者", value: "iChatAI Team")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Layout.cardRadius))
    }

    private var infoDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.05))
            .frame(height: 0.5)
            .padding(.horizontal, Layout.rowHorizontalPadding)
    }

    // MARK: - 版权

    private var copyrightNote: some View {
        Text(copyright)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    // MARK: - 卡片标题

    private func cardHeader(icon: String, iconColor: Color, title: String) -> some View {
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
        .padding(.horizontal, Layout.rowHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

// MARK: - 信息行（重命名避免与 SettingsView 中的 InfoRow 冲突）

private struct AboutInfoRow: View {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AboutView()
    }
}
