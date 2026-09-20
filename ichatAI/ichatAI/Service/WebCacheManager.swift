// WebCacheManager.swift
import Foundation
import WebKit
import Observation

struct CacheItem: Identifiable {
    let id: String
    let name: String
    let type: String
    var size: Int64

    var formattedSize: String {
        switch size {
        case -1: return "驻留内存"
        case 0:  return "无占用"
        default: return "≈ \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
        }
    }
}

@MainActor
@Observable
final class WebCacheManager {
    private(set) var cacheItems: [CacheItem] = []
    private(set) var isLoading = false

    @ObservationIgnored
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

    var totalFormattedSize: String {
        let total = cacheItems.reduce(Int64(0)) { $0 + max(0, $1.size) }
        return total == 0 ? "Zero KB"
            : ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    func fetchCacheSizes() {
        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let items = await self.buildCacheItems()
            self.cacheItems = items
            self.isLoading = false
        }
    }

    private func buildCacheItems() async -> [CacheItem] {
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let records: [WKWebsiteDataRecord] = await withCheckedContinuation { cont in
            dataStore.fetchDataRecords(ofTypes: Set(allTypes)) { records in
                cont.resume(returning: records)
            }
        }

        var existingTypes = Set<String>()
        for record in records {
            for dataType in record.dataTypes { existingTypes.insert(dataType) }
        }

        if existingTypes.isEmpty {
            existingTypes.formUnion([
                WKWebsiteDataTypeDiskCache,
                WKWebsiteDataTypeCookies,
                WKWebsiteDataTypeLocalStorage,
                WKWebsiteDataTypeIndexedDBDatabases,
            ])
        }

        var scannedPaths = Set<String>()
        var items: [CacheItem] = []

        for type in existingTypes.sorted() {
            if type == WKWebsiteDataTypeMemoryCache {
                items.append(CacheItem(id: type, name: typeNames[type] ?? type, type: type, size: -1))
                continue
            }

            let urls = Self.paths(for: type)
            var totalSize: Int64 = 0
            for url in urls {
                let normalized = url.standardized.path
                guard !scannedPaths.contains(normalized) else { continue }
                scannedPaths.insert(normalized)
                totalSize += Self.size(at: url)
            }

            items.append(CacheItem(id: type, name: typeNames[type] ?? type, type: type, size: totalSize))
        }

        return items.sorted { $0.size > $1.size }
    }

    func clearSelected(types: Set<String>) async -> Bool {
        guard !types.isEmpty else { return false }
        let cleanable = types.filter { $0 != WKWebsiteDataTypeMemoryCache }
        guard !cleanable.isEmpty else { return false }
        await dataStore.removeData(ofTypes: cleanable, modifiedSince: .distantPast)
        // WebKit 删除并非同步完成，延迟一点再让 UI 重新扫描
        try? await Task.sleep(for: .milliseconds(400))
        return true
    }

    // MARK: - 路径映射（纯函数，nonisolated）
    nonisolated private static func paths(for type: String) -> [URL] {
        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? ""

        switch type {
        case WKWebsiteDataTypeDiskCache:
            return [
                library.appendingPathComponent("Caches/WebKit/NetworkCache"),
                library.appendingPathComponent("Caches/WebKit/CacheStorage"),
                library.appendingPathComponent("Caches/\(bundleID)/WebKit/NetworkCache"),
                library.appendingPathComponent("Caches/\(bundleID)/WebKit/CacheStorage")
            ]
        case WKWebsiteDataTypeCookies:
            return [
                library.appendingPathComponent("Cookies"),
                library.appendingPathComponent("WebKit/\(bundleID)/WebsiteData/Cookies.db"),
                library.appendingPathComponent("WebKit/WebsiteData/Cookies.db")
            ]
        case WKWebsiteDataTypeIndexedDBDatabases:
            return [
                library.appendingPathComponent("WebKit/WebsiteData/IndexedDB"),
                library.appendingPathComponent("WebKit/\(bundleID)/WebsiteData/IndexedDB")
            ]
        case WKWebsiteDataTypeLocalStorage:
            return [
                library.appendingPathComponent("WebKit/WebsiteData/LocalStorage"),
                library.appendingPathComponent("WebKit/\(bundleID)/WebsiteData/LocalStorage")
            ]
        default:
            return []
        }
    }

    nonisolated private static func size(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return 0 }

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let isDir = values?.isDirectory ?? false

        if !isDir { return Int64(values?.fileSize ?? 0) }

        var total: Int64 = 0
        if let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: []
        ) {
            for case let fileURL as URL in enumerator {
                let v = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if v?.isDirectory == false {
                    total += Int64(v?.fileSize ?? 0)
                }
            }
        }
        return total
    }
}
