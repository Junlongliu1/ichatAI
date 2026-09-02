import Foundation
import WebKit
import Combine

struct CacheItem: Identifiable {
    let id: String
    let name: String
    let type: String
    var size: Int64
    
    var formattedSize: String {
        switch size {
        case -1:
            return "驻留内存"
        case 0:
            return "无占用"
        default:
            let formatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            return "≈ \(formatted)"
        }
    }
}

// MARK: - 缓存管理器

class WebCacheManager: ObservableObject {
    @Published var cacheItems: [CacheItem] = []
    @Published var isLoading = false
    
    private let dataStore = WKWebsiteDataStore.default()
    
    private let typeNames: [String: String] = [
        WKWebsiteDataTypeDiskCache: "磁盘缓存",
        WKWebsiteDataTypeMemoryCache: "内存缓存",
        WKWebsiteDataTypeCookies: "Cookie / 登录态",
        WKWebsiteDataTypeLocalStorage: "本地存储",
        WKWebsiteDataTypeSessionStorage: "会话存储",
        WKWebsiteDataTypeIndexedDBDatabases: "IndexedDB 数据库",
        WKWebsiteDataTypeWebSQLDatabases: "WebSQL 数据库",
        WKWebsiteDataTypeServiceWorkerRegistrations: "Service Worker",
        WKWebsiteDataTypeFetchCache: "Fetch API 缓存"
    ]
    
    /// App 总存储占用（仅统计可量化的磁盘部分）
    var totalFormattedSize: String {
        let total = cacheItems.reduce(Int64(0)) { result, item in
            item.size > 0 ? result + item.size : result
        }
        if total == 0 { return "Zero KB" }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    func fetchCacheSizes() {
        isLoading = true
        
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            
            let items = await self.buildCacheItems()
            
            await MainActor.run {
                self.cacheItems = items
                self.isLoading = false
            }
        }
    }
    
    /// 纯 API 驱动构建缓存列表
    private func buildCacheItems() async -> [CacheItem] {
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        let records: [WKWebsiteDataRecord] = await withCheckedContinuation { continuation in
            dataStore.fetchDataRecords(ofTypes: allTypes) { records in
                continuation.resume(returning: records)
            }
        }
        
        var existingTypes = Set<String>()
        for record in records {
            for dataType in record.dataTypes {
                existingTypes.insert(dataType)
            }
        }
        
        #if DEBUG
        AppLog("[WebCache] API 返回类型: \(existingTypes.isEmpty ? "(空)" : existingTypes.sorted().joined(separator: ", "))")
        #endif
        
        var items: [CacheItem] = []
        for type in existingTypes {
            let size: Int64
            if type == WKWebsiteDataTypeMemoryCache {
                size = -1
            } else {
                let recordCount = records.filter { $0.dataTypes.contains(type) }.count
                size = Int64(recordCount) * 1024
            }
            
            items.append(CacheItem(
                id: type,
                name: typeNames[type] ?? type,
                type: type,
                size: size
            ))
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    /// 按选中类型清理缓存
    func clearSelected(types: Set<String>) async -> Bool {
        guard !types.isEmpty else { return false }
        
        let cleanableTypes = types.filter { $0 != WKWebsiteDataTypeMemoryCache }
        guard !cleanableTypes.isEmpty else { return false }
        
        await dataStore.removeData(ofTypes: cleanableTypes, modifiedSince: Date.distantPast)
        return true
    }
}
