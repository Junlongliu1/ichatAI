// AIService.swift
import SwiftUI
import Foundation
import Observation

struct AIService: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var url: String
    var isBuiltIn: Bool

    init(id: String = UUID().uuidString, name: String, url: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.isBuiltIn = isBuiltIn
    }
}

extension AIService {
    static let builtInServices: [AIService] = [
        AIService(id: "doubao",   name: "豆包",     url: "https://www.doubao.com/chat/",             isBuiltIn: true),
        AIService(id: "yiyan",    name: "文心一言", url: "https://yiyan.baidu.com",                   isBuiltIn: true),
        AIService(id: "tongyi",   name: "通义千问", url: "https://www.qianwen.com/?source=tongyigw",  isBuiltIn: true),
        AIService(id: "kimi",     name: "Kimi",     url: "https://kimi.moonshot.cn",                  isBuiltIn: true),
        AIService(id: "deepseek", name: "DeepSeek", url: "https://chat.deepseek.com",                 isBuiltIn: true),
        AIService(id: "yuanbao",  name: "腾讯元宝", url: "https://yuanbao.tencent.com",               isBuiltIn: true),
        AIService(id: "chatgpt",  name: "ChatGPT",  url: "https://chatgpt.com",                       isBuiltIn: true),
        AIService(id: "gemini",   name: "Gemini",   url: "https://gemini.google.com",                 isBuiltIn: true),
        AIService(id: "grok",     name: "Grok",     url: "https://grok.com",                          isBuiltIn: true),
    ]
}

@MainActor
@Observable
final class AIServiceManager {
    static let shared = AIServiceManager()

    private let customKey = "customAIServices"
    private let visibleKey = "visibleAIServiceIDs"
    private let defaultServiceKey = "defaultServiceID"

    private(set) var customServices: [AIService] = []
    private(set) var visibleServiceIDs: Set<String> = []
    private(set) var defaultServiceID: String = "doubao"

    /// B7：缓存合并后的服务列表（避免每次计算属性都拼数组）
    private(set) var allServices: [AIService] = []

    private init() {
        self.defaultServiceID = UserDefaults.standard.string(forKey: defaultServiceKey) ?? "doubao"
        loadCustomServices()
        loadVisibleIDs()
        rebuildAllServices()
        normalize()
    }

    // MARK: - 派生
    var visibleServices: [AIService] {
        let visible = visibleServiceIDs
        return allServices.filter { visible.contains($0.id) }
    }

    var defaultService: AIService {
        allServices.first(where: { $0.id == defaultServiceID })
            ?? AIService.builtInServices[0]
    }

    // MARK: - 增删改
    func addCustomService(name: String, url: String) {
        let service = AIService(name: name, url: url)
        customServices.append(service)
        visibleServiceIDs.insert(service.id)
        rebuildAllServices()
        saveCustomServices()
        saveVisibleIDs()
    }

    func updateCustomService(_ service: AIService) {
        guard let idx = customServices.firstIndex(where: { $0.id == service.id }) else { return }
        customServices[idx] = service
        rebuildAllServices()
        saveCustomServices()
    }

    func deleteCustomService(_ service: AIService) {
        customServices.removeAll { $0.id == service.id }
        visibleServiceIDs.remove(service.id)
        if defaultServiceID == service.id {
            defaultServiceID = AIService.builtInServices.first?.id ?? "doubao"
            UserDefaults.standard.set(defaultServiceID, forKey: defaultServiceKey)
        }
        rebuildAllServices()
        normalize()
        saveCustomServices()
        saveVisibleIDs()
    }

    func setDefaultService(_ id: String) {
        guard allServices.contains(where: { $0.id == id }) else { return }
        defaultServiceID = id
        UserDefaults.standard.set(id, forKey: defaultServiceKey)
    }

    func toggleVisibility(_ id: String) {
        if visibleServiceIDs.contains(id) {
            guard visibleServiceIDs.count > 1 else { return }
            visibleServiceIDs.remove(id)
        } else {
            visibleServiceIDs.insert(id)
        }
        saveVisibleIDs()
    }

    func setVisible(_ ids: Set<String>) {
        let allIDs = Set(allServices.map(\.id))
        var cleaned = ids.intersection(allIDs)
        if cleaned.isEmpty, let first = allServices.first?.id {
            cleaned = [first]
        }
        visibleServiceIDs = cleaned
        saveVisibleIDs()
    }

    // MARK: - 一致性
    private func normalize() {
        let allIDs = Set(allServices.map(\.id))

        let cleaned = visibleServiceIDs.intersection(allIDs)
        if cleaned != visibleServiceIDs { visibleServiceIDs = cleaned }

        if !allIDs.contains(defaultServiceID) {
            defaultServiceID = AIService.builtInServices.first?.id ?? "doubao"
            UserDefaults.standard.set(defaultServiceID, forKey: defaultServiceKey)
        }

        if visibleServiceIDs.isEmpty {
            if allIDs.contains(defaultServiceID) {
                visibleServiceIDs = [defaultServiceID]
            } else if let first = AIService.builtInServices.first?.id {
                visibleServiceIDs = [first]
            }
        }
    }

    private func rebuildAllServices() {
        allServices = AIService.builtInServices + customServices
    }

    // MARK: - 持久化
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
            visibleServiceIDs = Set(AIService.builtInServices.map(\.id))
        }
    }
}
