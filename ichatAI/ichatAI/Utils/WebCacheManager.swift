// 缓存管理器

import Foundation
import WebKit
import Combine

//  单个缓存类型及其相关的大小
struct CacheItem: Identifiable {
    let id: String                  // 数据类型
    let name: String                // 显示名称
    let type: String                // 类型描述
    var size: Int64                 // 缓存大小（字节），-1 表示驻留内存，0 表示无占用
    
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

//  缓存管理器，负责扫描、计算和清理 WebKit 缓存
class WebCacheManager: ObservableObject {
    @Published var cacheItems: [CacheItem] = []             // 扫描到的缓存类型及其大小
    @Published var isLoading = false                        // 是否正在扫描缓存
    
    private let dataStore = WKWebsiteDataStore.default()    // 默认数据存储
    
    // 映射 WKWebsiteDataType 到可读名称
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
    
    //  扫描指定类型的缓存路径，返回对应的 URL 列表
    private func paths(for type: String) -> [URL] {
        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        
        switch type {
        case WKWebsiteDataTypeDiskCache:
            return [
                // 真机路径（无 bundleID）
                library.appendingPathComponent("Caches/WebKit/NetworkCache"),
                library.appendingPathComponent("Caches/WebKit/CacheStorage"),
                // 模拟器路径（有 bundleID）
                library.appendingPathComponent("Caches/\(bundleID)/WebKit/NetworkCache"),
                library.appendingPathComponent("Caches/\(bundleID)/WebKit/CacheStorage")
            ]
            
        case WKWebsiteDataTypeCookies:
            return [
                // 真机 & 模拟器通用
                library.appendingPathComponent("Cookies"),
                // 模拟器兜底
                library.appendingPathComponent("WebKit/\(bundleID)/WebsiteData/Cookies.db"),
                // 真机兜底
                library.appendingPathComponent("WebKit/WebsiteData/Cookies.db")
            ]
            
        case WKWebsiteDataTypeIndexedDBDatabases:
            return [
                // 真机路径
                library.appendingPathComponent("WebKit/WebsiteData/IndexedDB"),
                // 模拟器路径
                library.appendingPathComponent("WebKit/\(bundleID)/WebsiteData/IndexedDB")
            ]
            
        case WKWebsiteDataTypeLocalStorage:
            return [
                // 真机路径
                library.appendingPathComponent("WebKit/WebsiteData/LocalStorage"),
                // 模拟器路径
                library.appendingPathComponent("WebKit/\(bundleID)/WebsiteData/LocalStorage")
            ]
            
        case WKWebsiteDataTypeSessionStorage:
            // 纯内存存储，无磁盘文件
            return []
            
        default:
            return []
        }
    }
    
    //  计算指定 URL 的大小（字节），支持文件和目录，目录会递归计算总大小
    private func size(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            AppLog("[Size] 不存在: \(url.path)")
            return 0
        }
        
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let isDir = values?.isDirectory ?? false
        
        if !isDir {
            return Int64(values?.fileSize ?? 0)
        }
        
        // 递归计算目录大小
        var totalSize: Int64 = 0
        if let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: []
        ) {
            for case let fileURL as URL in enumerator {
                let fileValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if fileValues?.isDirectory == false {
                    totalSize += Int64(fileValues?.fileSize ?? 0)
                }
            }
        }
        AppLog("[Size] DIR \(url.lastPathComponent) | recursive_size=\(totalSize) bytes")
        return totalSize
    }
    
    //  计算所有缓存类型的总大小，返回格式化字符串
    var totalFormattedSize: String {
        let total = cacheItems.reduce(Int64(0)) { result, item in
            item.size > 0 ? result + item.size : result
        }
        if total == 0 { return "Zero KB" }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    //  扫描所有缓存类型，计算大小并更新 cacheItems
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
    
    //  构建缓存项列表，扫描所有类型并计算大小
    private func buildCacheItems() async -> [CacheItem] {
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let records: [WKWebsiteDataRecord] = await withCheckedContinuation { continuation in
            dataStore.fetchDataRecords(ofTypes: Set(allTypes)) { records in
                continuation.resume(returning: records)
            }
        }
        
        var existingTypes = Set<String>()           // 记录所有已存在的缓存类型
        //  遍历所有记录，收集其数据类型
        for record in records {
            for dataType in record.dataTypes {
                existingTypes.insert(dataType)
            }
        }
        
        // 兜底：API 未返回时仍扫描 DiskCache
        if existingTypes.isEmpty {
            existingTypes.insert(WKWebsiteDataTypeDiskCache)
        }
        
        var scannedPaths = Set<String>()            // 避免重复扫描同一路径
        var items: [CacheItem] = []                 // 结果缓存项列表
        
        //  遍历所有已存在的缓存类型，计算大小并构建 CacheItem
        for type in existingTypes.sorted() {
            if type == WKWebsiteDataTypeMemoryCache {
                items.append(CacheItem(id: type, name: typeNames[type] ?? type, type: type, size: -1))
                continue
            }
            
            let urls = paths(for: type)
            var totalSize: Int64 = 0
            for url in urls {
                let normalized = url.standardized.path
                guard !scannedPaths.contains(normalized) else { continue }
                scannedPaths.insert(normalized)
                totalSize += size(at: url)
            }
            
            items.append(CacheItem(
                id: type,
                name: typeNames[type] ?? type,
                type: type,
                size: totalSize
            ))
        }
        
        return items.sorted { $0.size > $1.size }
    }
    
    //  清理指定类型的缓存，返回是否成功
    func clearSelected(types: Set<String>) async -> Bool {
        guard !types.isEmpty else { return false }
        let cleanableTypes = types.filter { $0 != WKWebsiteDataTypeMemoryCache }
        guard !cleanableTypes.isEmpty else { return false }
        await dataStore.removeData(ofTypes: cleanableTypes, modifiedSince: Date.distantPast)
        return true
    }
}
