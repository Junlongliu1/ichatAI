// AILogo.swift
// AI logo 类型识别 + 品牌色
import SwiftUI

enum AILogo: Equatable {
    case openAI, anthropic, gemini
    case kimi, deepseek, doubao
    case ernie, qwen, yuanbao
    case grok, copilot
    case custom

    // MARK: 名称检测（大小写不敏感，支持别名）
    static func detect(from rawName: String) -> AILogo {
        let n = rawName.lowercased().trimmingCharacters(in: .whitespaces)

        if n.contains("chatgpt") || n.contains("openai") || n == "gpt" || n.hasPrefix("gpt-") {
            return .openAI
        }
        if n.contains("claude") || n.contains("anthropic") { return .anthropic }
        if n.contains("gemini") || n.contains("bard") { return .gemini }
        if n.contains("kimi") || n.contains("moonshot") { return .kimi }
        if n.contains("deepseek") { return .deepseek }
        if n.contains("豆包") || n.contains("doubao") { return .doubao }
        if n.contains("文心") || n.contains("ernie") { return .ernie }
        if n.contains("通义") || n.contains("qwen") { return .qwen }
        if n.contains("元宝") || n.contains("hunyuan") { return .yuanbao }
        if n.contains("grok") { return .grok }
        if n.contains("copilot") { return .copilot }
        return .custom
    }

    // MARK: 品牌色（未识别返回空数组）
    var brandColors: [Color] {
        switch self {
        case .openAI:    return [Color(hex: 0x10A37F), Color(hex: 0x0D8467)]
        case .anthropic: return [Color(hex: 0xDA7756), Color(hex: 0xB85A3E)]
        case .gemini:    return [Color(hex: 0x4285F4), Color(hex: 0x1A73E8)]
        case .kimi:      return [Color(hex: 0x1A1A2E), Color(hex: 0x0F0F1E)]
        case .deepseek:  return [Color(hex: 0x4D6BFE), Color(hex: 0x2E47CC)]
        case .doubao:    return [Color(hex: 0x2D6BFF), Color(hex: 0x1A4FCC)]
        case .ernie:     return [Color(hex: 0x2932E1), Color(hex: 0x1B22B8)]
        case .qwen:      return [Color(hex: 0x6C5CE7), Color(hex: 0x4834D4)]
        case .yuanbao:   return [Color(hex: 0x07C160), Color(hex: 0x05A350)]
        case .grok:      return [Color(hex: 0x111111), Color(hex: 0x2A2A2A)]
        case .copilot:   return [Color(hex: 0x0078D4), Color(hex: 0x005A9E)]
        case .custom:    return []
        }
    }
}
