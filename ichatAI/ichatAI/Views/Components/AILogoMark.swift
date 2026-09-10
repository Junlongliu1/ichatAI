// AILogoMark.swift
// 用 Canvas 手绘各大 AI 的简化 logo
import SwiftUI

struct AILogoMark: View {
    let name: String
    var size: CGFloat = 26

    var body: some View {
        Canvas { context, canvasSize in
            let logo = AILogo.detect(from: name)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let R = min(canvasSize.width, canvasSize.height) * 0.5

            switch logo {
            case .openAI:    Self.drawOpenAI(context: &context, center: center, R: R)
            case .anthropic: Self.drawAnthropic(context: &context, center: center, R: R)
            case .gemini:    Self.drawGemini(context: &context, center: center, R: R)
            case .kimi:      Self.drawKimi(context: &context, center: center, R: R)
            case .deepseek:  Self.drawDeepSeek(context: &context, center: center, R: R)
            case .doubao:    Self.drawDoubao(context: &context, center: center, R: R)
            case .ernie:     Self.drawErnie(context: &context, center: center, R: R)
            case .qwen:      Self.drawQwen(context: &context, center: center, R: R)
            case .yuanbao:   Self.drawYuanbao(context: &context, center: center, R: R)
            case .grok:      Self.drawGrok(context: &context, center: center, R: R)
            case .copilot:   Self.drawCopilot(context: &context, center: center, R: R)
            case .custom:    Self.drawFallback(context: &context, name: name, size: canvasSize)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

// MARK: - 各品牌 Logo 绘制
private extension AILogoMark {

    // 1. OpenAI —— 6 个交错椭圆，形成"缠绕"球体
    static func drawOpenAI(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        let lw = R * 0.11
        let baseEllipse = CGRect(
            x: -R * 0.62,
            y: -R * 0.20,
            width: R * 1.24,
            height: R * 0.40
        )
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3
            let transform = CGAffineTransform(rotationAngle: angle)
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
            let path = Path(ellipseIn: baseEllipse).applying(transform)
            context.stroke(
                path,
                with: .color(.white),
                style: StrokeStyle(lineWidth: lw, lineCap: .round)
            )
        }
    }

    // 2. Anthropic —— 8 道长短交替的星芒
    static func drawAnthropic(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        let lw = R * 0.16
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4 - .pi / 2
            let len: CGFloat = (i % 2 == 0) ? R * 0.90 : R * 0.52
            let start: CGFloat = R * 0.10

            var path = Path()
            path.move(to: CGPoint(
                x: center.x + cos(angle) * start,
                y: center.y + sin(angle) * start
            ))
            path.addLine(to: CGPoint(
                x: center.x + cos(angle) * len,
                y: center.y + sin(angle) * len
            ))
            context.stroke(
                path,
                with: .color(.white),
                style: StrokeStyle(lineWidth: lw, lineCap: .round)
            )
        }
    }

    // 3. Gemini —— 四角星
    static func drawGemini(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        let outer = R * 0.90
        let inner = R * 0.28

        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - outer))
        path.addQuadCurve(
            to: CGPoint(x: center.x + outer, y: center.y),
            control: CGPoint(x: center.x + inner, y: center.y - inner)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y + outer),
            control: CGPoint(x: center.x + inner, y: center.y + inner)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x - outer, y: center.y),
            control: CGPoint(x: center.x - inner, y: center.y + inner)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y - outer),
            control: CGPoint(x: center.x - inner, y: center.y - inner)
        )
        path.closeSubpath()
        context.fill(path, with: .color(.white))
    }

    // 4. Kimi —— 月牙（两圆 eoFill）
    static func drawKimi(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - R * 0.95, y: center.y - R * 0.90,
            width: R * 1.80, height: R * 1.80
        ))
        path.addEllipse(in: CGRect(
            x: center.x - R * 0.50, y: center.y - R * 0.90,
            width: R * 1.80, height: R * 1.80
        ))
        context.fill(
            path,
            with: .color(.white),
            style: FillStyle(eoFill: true)
        )
    }

    // 5. DeepSeek —— 鲸鱼（椭圆身体 + 三角尾 + 挖空眼睛）
    static func drawDeepSeek(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        let body = Path(ellipseIn: CGRect(
            x: center.x - R * 0.72, y: center.y - R * 0.38,
            width: R * 1.30, height: R * 0.76
        ))
        context.fill(body, with: .color(.white))

        var tail = Path()
        tail.move(to: CGPoint(x: center.x + R * 0.45, y: center.y))
        tail.addLine(to: CGPoint(x: center.x + R * 0.98, y: center.y - R * 0.45))
        tail.addLine(to: CGPoint(x: center.x + R * 0.55, y: center.y + R * 0.05))
        tail.addLine(to: CGPoint(x: center.x + R * 0.98, y: center.y + R * 0.45))
        tail.closeSubpath()
        context.fill(tail, with: .color(.white))

        context.drawLayer { layer in
            layer.blendMode = .destinationOut
            let eyeRect = CGRect(
                x: center.x - R * 0.42, y: center.y - R * 0.15,
                width: R * 0.18, height: R * 0.18
            )
            layer.fill(Path(ellipseIn: eyeRect), with: .color(.black))
        }
    }

    // 6. 豆包 —— 旋转的豆子
    static func drawDoubao(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        context.drawLayer { layer in
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: -.pi / 6)
                .translatedBy(x: -center.x, y: -center.y)
            layer.transform = transform

            let rect = CGRect(
                x: center.x - R * 0.58, y: center.y - R * 0.72,
                width: R * 1.16, height: R * 1.44
            )
            layer.fill(Path(ellipseIn: rect), with: .color(.white))
        }

        context.drawLayer { layer in
            layer.blendMode = .destinationOut
            let hl = CGRect(
                x: center.x - R * 0.32, y: center.y - R * 0.40,
                width: R * 0.22, height: R * 0.30
            )
            layer.fill(Path(ellipseIn: hl), with: .color(.black))
        }
    }

    // 7. 文心一言 —— W 形
    static func drawErnie(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        let lw = R * 0.22
        var path = Path()
        path.move(to: CGPoint(x: center.x - R * 0.78, y: center.y - R * 0.55))
        path.addLine(to: CGPoint(x: center.x - R * 0.36, y: center.y + R * 0.60))
        path.addLine(to: CGPoint(x: center.x,             y: center.y - R * 0.15))
        path.addLine(to: CGPoint(x: center.x + R * 0.36, y: center.y + R * 0.60))
        path.addLine(to: CGPoint(x: center.x + R * 0.78, y: center.y - R * 0.55))

        context.stroke(
            path,
            with: .color(.white),
            style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
        )
    }

    // 8. 通义千问 —— Q 形
    static func drawQwen(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        let lw = R * 0.22
        let ring = Path(ellipseIn: CGRect(
            x: center.x - R * 0.72, y: center.y - R * 0.85,
            width: R * 1.44, height: R * 1.44
        ))
        context.stroke(ring, with: .color(.white), style: StrokeStyle(lineWidth: lw))

        var tail = Path()
        tail.move(to: CGPoint(x: center.x + R * 0.18, y: center.y + R * 0.38))
        tail.addLine(to: CGPoint(x: center.x + R * 0.78, y: center.y + R * 0.90))
        context.stroke(
            tail,
            with: .color(.white),
            style: StrokeStyle(lineWidth: lw, lineCap: .round)
        )
    }

    // 9. 腾讯元宝 —— 船形
    static func drawYuanbao(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: center.x - R * 0.88, y: center.y - R * 0.22))
        path.addQuadCurve(
            to: CGPoint(x: center.x + R * 0.88, y: center.y - R * 0.22),
            control: CGPoint(x: center.x, y: center.y - R * 0.60)
        )
        path.addQuadCurve(
            to: CGPoint(x: center.x - R * 0.88, y: center.y - R * 0.22),
            control: CGPoint(x: center.x, y: center.y + R * 0.70)
        )
        path.closeSubpath()
        context.fill(path, with: .color(.white))
    }

    // 10. Grok —— X 形
    static func drawGrok(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        let lw = R * 0.28
        var path = Path()
        path.move(to: CGPoint(x: center.x - R * 0.70, y: center.y - R * 0.70))
        path.addLine(to: CGPoint(x: center.x + R * 0.70, y: center.y + R * 0.70))
        path.move(to: CGPoint(x: center.x + R * 0.70, y: center.y - R * 0.70))
        path.addLine(to: CGPoint(x: center.x - R * 0.70, y: center.y + R * 0.70))
        context.stroke(
            path,
            with: .color(.white),
            style: StrokeStyle(lineWidth: lw, lineCap: .round)
        )
    }

    // 11. Copilot —— 2×2 方块
    static func drawCopilot(context: inout GraphicsContext, center: CGPoint, R: CGFloat) {
        let cell = R * 0.62
        let gap: CGFloat = R * 0.10
        let total = cell * 2 + gap
        let startX = center.x - total / 2
        let startY = center.y - total / 2

        for row in 0..<2 {
            for col in 0..<2 {
                let x = startX + CGFloat(col) * (cell + gap)
                let y = startY + CGFloat(row) * (cell + gap)
                let rect = CGRect(x: x, y: y, width: cell, height: cell)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: cell * 0.18),
                    with: .color(.white)
                )
            }
        }
    }

    // 12. 未识别 —— 文字兜底
    static func drawFallback(
        context: inout GraphicsContext,
        name: String,
        size: CGSize
    ) {
        let display: String = {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard let first = trimmed.first else { return "?" }
            if !first.isASCII { return String(first) }
            let letters = trimmed.filter { $0.isLetter }
            return String(letters.prefix(2)).uppercased()
        }()

        let isChinese = display.first.map { !$0.isASCII } ?? false
        let font: Font = isChinese
            ? .system(size: size.width * 0.5, weight: .bold)
            : .system(size: size.width * 0.42, weight: .heavy)

        let resolved = context.resolve(
            Text(display)
                .font(font)
                .foregroundStyle(.white)
        )
        context.draw(
            resolved,
            at: CGPoint(x: size.width / 2, y: size.height / 2),
            anchor: .center
        )
    }
}
