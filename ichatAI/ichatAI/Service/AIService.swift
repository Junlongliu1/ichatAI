import SwiftUI

enum AIService: String, CaseIterable, Identifiable {
    case doubao = "豆包"
    case yiyan = "文心一言"
    case tongyi = "通义千问"
    case kimi = "Kimi"
    case deepseek = "DeepSeek"
    case yuanbao = "腾讯元宝"
    case chatgpt = "ChatGPT"
    case gemini = "Gemini"
    case grok = "Grok"
    
    var id: String { rawValue }
    
    var url: String {
        switch self {
        case .doubao:   return "https://www.doubao.com/chat/"
        case .yiyan:    return "https://yiyan.baidu.com"
        case .tongyi:   return "https://www.qianwen.com/?source=tongyigw"
        case .kimi:     return "https://kimi.moonshot.cn"
        case .deepseek: return "https://chat.deepseek.com"
        case .yuanbao:  return "https://yuanbao.tencent.com"
        case .chatgpt:  return "https://chatgpt.com"
        case .gemini:   return "https://gemini.google.com"
        case .grok:     return "https://grok.com"
        }
    }
    
    var icon: String {
        switch self {
        case .doubao:   return "sparkles"
        case .yiyan:    return "brain.head.profile"
        case .tongyi:   return "cloud.fill"
        case .kimi:     return "moon.stars.fill"
        case .deepseek: return "magnifyingglass.circle.fill"
        case .yuanbao:  return "yensign.circle.fill"
        case .chatgpt:  return "message.fill"
        case .gemini:   return "star.fill"
        case .grok:     return "bolt.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .doubao:   return .blue
        case .yiyan:    return .red
        case .tongyi:   return .orange
        case .kimi:     return .indigo
        case .deepseek: return .cyan
        case .yuanbao:  return .yellow
        case .chatgpt:  return .green
        case .gemini:   return .purple
        case .grok:     return .mint
        }
    }
}
