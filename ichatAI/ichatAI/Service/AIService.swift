// AI服务模型与管理器

import SwiftUI
import Combine
import Foundation

struct AIService: Identifiable, Codable, Hashable {
    let id: String          // 唯一标识符
    var name: String        // 服务名称
    var url: String         // 服务网址 
    var isBuiltIn: Bool     // 是否为内置服务
    
    // 初始化器，允许自定义ID，默认使用UUID
    init(id: String = UUID().uuidString, name: String, url: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.isBuiltIn = isBuiltIn
    }
}

// 预设服务与存储管理
extension AIService {
    static let builtInServices: [AIService] = [
        AIService(id: "doubao", name: "豆包", url: "https://www.doubao.com/chat/", isBuiltIn: true),
        AIService(id: "yiyan", name: "文心一言", url: "https://yiyan.baidu.com", isBuiltIn: true),
        AIService(id: "tongyi", name: "通义千问", url: "https://www.qianwen.com/?source=tongyigw", isBuiltIn: true),
        AIService(id: "kimi", name: "Kimi", url: "https://kimi.moonshot.cn", isBuiltIn: true),
        AIService(id: "deepseek", name: "DeepSeek", url: "https://chat.deepseek.com", isBuiltIn: true),
        AIService(id: "yuanbao", name: "腾讯元宝", url: "https://yuanbao.tencent.com", isBuiltIn: true),
        AIService(id: "chatgpt", name: "ChatGPT", url: "https://chatgpt.com", isBuiltIn: true),
        AIService(id: "gemini", name: "Gemini", url: "https://gemini.google.com", isBuiltIn: true),
        AIService(id: "grok", name: "Grok", url: "https://grok.com", isBuiltIn: true),
    ]
}

// 全局服务管理器
class AIServiceManager: ObservableObject {
    static let shared = AIServiceManager()
    
    @Published var customServices: [AIService] = [] {
        didSet { saveCustomServices() }
    }
    
    @Published var visibleServiceIDs: Set<String> = [] {
        didSet { saveVisibleIDs() }
    }
    
    @AppStorage("defaultServiceID") var defaultServiceID: String = "doubao"
    
    private let customKey = "customAIServices"
    private let visibleKey = "visibleAIServiceIDs"
    
    private init() {
        loadCustomServices()
        loadVisibleIDs()
    }
    
    /// 获取所有可用服务（内置 + 自定义）
    var allServices: [AIService] {
        AIService.builtInServices + customServices
    }
    
    /// 获取当前应显示的服务列表
    var visibleServices: [AIService] {
        allServices.filter { visibleServiceIDs.contains($0.id) }
    }
    
    /// 获取默认启动服务
    var defaultService: AIService {
        allServices.first(where: { $0.id == defaultServiceID }) ?? AIService.builtInServices[0]
    }
    
    // 自定义服务增删
    func addCustomService(name: String, url: String) {
        let service = AIService(name: name, url: url)
        customServices.append(service)
        visibleServiceIDs.insert(service.id)
    }
    
    func deleteCustomService(_ service: AIService) {
        customServices.removeAll { $0.id == service.id }
        visibleServiceIDs.remove(service.id)
        if defaultServiceID == service.id {
            defaultServiceID = "doubao"
        }
    }
    
    // 持久化
    private func saveCustomServices() {
        if let data = try? JSONEncoder().encode(customServices) {
            UserDefaults.standard.set(data, forKey: customKey)
        }
    }
    
    private func loadCustomServices() {
        if let data = UserDefaults.standard.data(forKey: customKey),
           let services = try? JSONDecoder().decode([AIService].self, from: data) {
            customServices = services
        }
    }
    
    private func saveVisibleIDs() {
        UserDefaults.standard.set(Array(visibleServiceIDs), forKey: visibleKey)
    }
    
    private func loadVisibleIDs() {
        if let ids = UserDefaults.standard.stringArray(forKey: visibleKey) {
            visibleServiceIDs = Set(ids)
        } else {
            // 首次启动默认全部可见
            visibleServiceIDs = Set(AIService.builtInServices.map(\.id))
        }
    }
}
