// FloatingActionMenu.swift
// 悬浮球 + 展开菜单
import SwiftUI

// MARK: - 共享尺寸常量
enum Metric {
    static let fabSize: CGFloat = 48
    static let fabTrailingPadding: CGFloat = 12
    static let menuGap: CGFloat = 10
    static let menuWidth: CGFloat = 208
    static let menuCornerRadius: CGFloat = 16
    static let rowHeight: CGFloat = 36
    static let rowSpacing: CGFloat = 2
    static let listVerticalPadding: CGFloat = 12
    static let maxVisibleRows = 5
}

// MARK: - 名称 → 配色（悬浮球和菜单行共用）
enum AvatarPalette {
    /// 稳定哈希：跨进程、跨设备、跨时间一致
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return hash
    }

    /// 品牌色优先；未识别 → hash 派生双色渐变
    static func gradient(for name: String) -> [Color] {
        let brand = AILogo.detect(from: name).brandColors
        if !brand.isEmpty { return brand }

        let hash = stableHash(name)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = (hue1 + 0.12).truncatingRemainder(dividingBy: 1.0)
        return [
            Color(hue: hue1, saturation: 0.72, brightness: 0.92),
            Color(hue: hue2, saturation: 0.86, brightness: 0.62)
        ]
    }

    /// 主色（用于阴影、选中背景）
    static func primary(for name: String) -> Color {
        gradient(for: name).first ?? .accentColor
    }
}

// MARK: - 悬浮球 + 展开菜单
struct FloatingActionMenu: View {
    let services: [AIService]
    @Binding var selectedService: AIService
    @Binding var isExpanded: Bool
    let onNavigate: (HomeView.ActiveSheet) -> Void

    var body: some View {
        triggerButton
            .overlay(alignment: .topTrailing) {
                if isExpanded {
                    compactMenuContent
                        .offset(y: Metric.fabSize + Metric.menuGap)
                        .transition(
                            .scale(scale: 0.9, anchor: .topTrailing)
                                .combined(with: .opacity)
                        )
                }
            }
    }

    // MARK: 悬浮球
    private var triggerButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                // 底面暗部
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.clear, Color.black.opacity(0.18)],
                            center: .init(x: 0.7, y: 0.8),
                            startRadius: 8,
                            endRadius: Metric.fabSize * 0.65
                        )
                    )

                // 主渐变
                Circle()
                    .fill(
                        LinearGradient(
                            colors: avatarGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // 左上柔光
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .blendMode(.overlay)
                    .allowsHitTesting(false)

                // 渐变描边
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
                    .allowsHitTesting(false)

                // 中心：LOGO ↔ ✕
                ZStack {
                    AILogoMark(name: selectedService.name, size: 26)
                        .opacity(isExpanded ? 0 : 1)

                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                        .opacity(isExpanded ? 1 : 0)
                }
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .frame(width: Metric.fabSize, height: Metric.fabSize)
            .shadow(
                color: avatarShadowColor.opacity(isExpanded ? 0.55 : 0.4),
                radius: isExpanded ? 14 : 10,
                y: 5
            )
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            .scaleEffect(isExpanded ? 1.04 : 1.0)
        }
        .buttonStyle(PressScaleButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selectedService.id)
    }

    private var avatarGradient: [Color] {
        AvatarPalette.gradient(for: selectedService.name)
    }

    private var avatarShadowColor: Color {
        avatarGradient.first ?? .accentColor
    }

    // MARK: 展开面板
    private var compactMenuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部功能栏
            HStack(spacing: 0) {
                CompactMenuIconButton(icon: "folder.fill", title: "文件") {
                    onNavigate(.files)
                }
                Divider().frame(height: 24).opacity(0.25)
                CompactMenuIconButton(icon: "gearshape.fill", title: "设置") {
                    onNavigate(.settings)
                }
            }
            .padding(.vertical, 10)

            // 服务列表
            if !services.isEmpty {
                Divider().padding(.horizontal, 12).opacity(0.25)

                ScrollView(.vertical, showsIndicators: services.count > Metric.maxVisibleRows) {
                    VStack(alignment: .leading, spacing: Metric.rowSpacing) {
                        ForEach(services) { service in
                            CompactServiceRow(
                                name: service.name,
                                isSelected: selectedService.id == service.id
                            )
                            .onTapGesture {
                                UISelectionFeedbackGenerator().selectionChanged()
                                selectedService = service
                                withAnimation(.spring(response: 0.3)) { isExpanded = false }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, Metric.listVerticalPadding / 2)
                }
                .frame(height: servicesAreaHeight)
            }
        }
        .frame(width: Metric.menuWidth)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: Metric.menuCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metric.menuCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }

    private var servicesAreaHeight: CGFloat {
        let rows = min(services.count, Metric.maxVisibleRows)
        guard rows > 0 else { return 0 }
        return CGFloat(rows) * Metric.rowHeight
            + CGFloat(rows - 1) * Metric.rowSpacing
            + Metric.listVerticalPadding
    }
}

// MARK: - 服务行（LOGO 圆底 + 品牌色选中）
private struct CompactServiceRow: View {
    let name: String
    let isSelected: Bool

    private var gradient: [Color] {
        AvatarPalette.gradient(for: name)
    }

    var body: some View {
        HStack(spacing: 10) {
            // LOGO 圆底
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                    )
                    .shadow(
                        color: (gradient.first ?? .black).opacity(0.25),
                        radius: 3,
                        y: 1
                    )

                AILogoMark(name: name, size: 14)
            }

            Text(name)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: Metric.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    gradient.first?.opacity(0.85) ?? .accentColor,
                                    gradient.last?.opacity(0.85) ?? .accentColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(Color.clear)
                )
        )
        .contentShape(Rectangle())
    }
}

// MARK: - 顶部功能按钮
private struct CompactMenuIconButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 按压缩放样式
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(
                .spring(response: 0.25, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}
