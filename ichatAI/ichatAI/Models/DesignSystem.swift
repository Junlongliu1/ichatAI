// DesignSystem.swift
import SwiftUI

// MARK: - 布局常量
enum DSLayout {
    static let cardRadius: CGFloat = 22
    static let cardSpacing: CGFloat = 14
    static let horizontalPadding: CGFloat = 16
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 12
    static let dividerLeading: CGFloat = 54
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
        .padding(.horizontal, DSLayout.rowHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

// MARK: - 行分隔线
struct SettingsRowDivider: View {
    var leading: CGFloat = DSLayout.dividerLeading

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.05))
            .frame(height: 0.5)
            .padding(.leading, leading)
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
                    .background(Capsule().fill(Color.secondary.opacity(0.10)))
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, DSLayout.rowHorizontalPadding)
        .padding(.vertical, DSLayout.rowVerticalPadding)
        .contentShape(Rectangle())
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

// MARK: - 图表配色
enum ChartColors {
    private static let palette: [Color] = [
        .blue, .orange, .green, .red, .purple,
        .pink, .yellow, .teal, .indigo, .mint
    ]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }

    /// 稳定哈希：相同 key 永远得到相同颜色
    static func stableColor(for key: String) -> Color {
        var h = 5381
        for c in key.unicodeScalars { h = ((h << 5) &+ h) &+ Int(c.value) }
        return palette[abs(h) % palette.count]
    }
}

// MARK: - Toast
struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
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
        .padding(.horizontal, DSLayout.rowHorizontalPadding)
        .padding(.vertical, DSLayout.rowVerticalPadding)
    }
}
