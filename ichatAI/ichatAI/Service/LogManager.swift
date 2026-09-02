import Foundation
import Combine

// MARK: - 全局快捷打印函数
func AppLog(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    let timestamp = formatter.string(from: Date())
    let formatted = "[\(timestamp)] [\(fileName):\(line)] \(function) -> \(message)"
    
    // 1. 输出到 Xcode 控制台
    print(formatted)
    
    // 2. 写入日志管理器
    LogManager.shared.write(formatted)
}

// MARK: - 日志管理器
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published private(set) var logContent: String = ""
    
    private var logFileURL: URL?
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.ichatai.logmanager", qos: .utility)
    
    // 配置参数
    private let maxFileSizeBytes: UInt64 = 10 * 1024 * 1024 // 10MB
    private let maxRetentionDays: Int = 7                    // 保留7天
    
    // 内存中追踪的文件大小，避免频繁读取磁盘
    private var currentFileSize: UInt64 = 0
    
    private var logsDirectory: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private init() {
        setupLogFile()
        cleanOldLogs() // ✅ 需求2：启动时立即清理旧日志
        loadTodayLog()
    }
    
    // MARK: - 初始化与文件设置
    
    private func setupLogFile() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = "\(formatter.string(from: Date())).log"
        let url = logsDirectory.appendingPathComponent(fileName)
        
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
            currentFileSize = 0
        } else {
            // 读取现有文件大小
            if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? UInt64 {
                currentFileSize = size
            }
        }
        
        logFileURL = url
    }
    
    // MARK: - 写入日志
    
    func write(_ message: String) {
        queue.async { [weak self] in
            guard let self, let url = self.logFileURL else { return }
            
            let data = (message + "\n").data(using: .utf8) ?? Data()
            
            // 检查是否需要轮转
            if self.currentFileSize + UInt64(data.count) >= self.maxFileSizeBytes {
                self.rollOverLogFile()
            }
            
            // 追加到文件
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
                self.currentFileSize += UInt64(data.count)
            }
            
            // 更新 UI
            DispatchQueue.main.async {
                self.logContent += message + "\n"
            }
        }
    }
    
    // MARK: - 文件轮转
    
    private func rollOverLogFile() {
        guard let url = logFileURL else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let archiveName = "\(formatter.string(from: Date())).log"
        let archiveURL = logsDirectory.appendingPathComponent(archiveName)
        
        // 将当前文件重命名为归档文件
        try? fileManager.moveItem(at: url, to: archiveURL)
        
        // 创建新的空文件
        fileManager.createFile(atPath: url.path, contents: nil)
        currentFileSize = 0
    }
    
    // MARK: - 清理旧日志
    
    private func cleanOldLogs() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxRetentionDays, to: Date()) ?? Date()
        
        guard let files = try? fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        
        for fileURL in files where fileURL.pathExtension == "log" {
            if let attributes = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = attributes.contentModificationDate,
               modDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    // MARK: - 加载与清空
    
    func loadTodayLog() {
        guard let url = logFileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            logContent = "无法读取日志文件"
            return
        }
        logContent = content
    }
    
    func clearTodayLog() {
        guard let url = logFileURL else { return }
        try? "".write(to: url, atomically: true, encoding: .utf8)
        currentFileSize = 0
        DispatchQueue.main.async { self.logContent = "" }
        AppLog("=== 日志已清空 ===")
    }
}
