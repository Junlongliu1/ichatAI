//
//  LogManager.swift
//  iNotion
//
//  日志管理器
//  - LogEntry：写入时解析一次（时间戳 / 内容 / 等级）
//  - 批量写盘：合并多次 write 为一次 I/O
//

import Foundation
import Observation

// MARK: - 日志等级

enum LogLevel: String {
    case error   = "ERROR"
    case warning = "WARN"
    case debug   = "DEBUG"
    case info    = "INFO"

    /// 写入文件时使用的标记，例如 "[ERROR]"
    var tag: String { "[\(rawValue)]" }

    static func detect(in line: String) -> LogLevel {
        if line.contains("[ERROR]") { return .error }
        if line.contains("[WARN]")  { return .warning }
        if line.contains("[DEBUG]") { return .debug }
        return .info
    }
}

// MARK: - 日志条目

struct LogEntry: Identifiable {
    let id: Int
    let timestamp: String?
    let rest: String
    let level: LogLevel
    /// 原始整行（用于复制 / 保存）
    let raw: String

    var lineNumber: Int { id + 1 }
}

// MARK: - 便捷日志函数（nonisolated，任意线程可调用）
//
// 内部通过 dispatchLog 分发：
// - 主线程：MainActor.assumeIsolated 同步执行，保序、零延迟
// - 后台线程：Task { @MainActor in ... } 异步转发
//
// 这样 @Model 类型的计算属性（非 MainActor 隔离）也能安全打日志。

nonisolated func AppLogInfo(_ message: Any,
                            file: String = #file,
                            function: String = #function,
                            line: Int = #line) {
    dispatchLog(message, level: .info, file: file, function: function, line: line)
}

nonisolated func AppLogWarn(_ message: Any,
                            file: String = #file,
                            function: String = #function,
                            line: Int = #line) {
    dispatchLog(message, level: .warning, file: file, function: function, line: line)
}

nonisolated func AppLogError(_ message: Any,
                             file: String = #file,
                             function: String = #function,
                             line: Int = #line) {
    dispatchLog(message, level: .error, file: file, function: function, line: line)
}

nonisolated func AppLogDebug(_ message: Any,
                             file: String = #file,
                             function: String = #function,
                             line: Int = #line) {
    dispatchLog(message, level: .debug, file: file, function: function, line: line)
}

// MARK: - 分发（nonisolated → MainActor）

nonisolated private func dispatchLog(_ message: Any,
                                     level: LogLevel,
                                     file: String,
                                     function: String,
                                     line: Int) {
    // 提前字符串化，避免 Any 跨 actor 传递
    let text = String(describing: message)

    // 拷贝参数，避免闭包捕获问题
    let f = file
    let fn = function
    let l = line

    if Thread.isMainThread {
        // 已在主线程：同步直发，保证顺序和时效
        MainActor.assumeIsolated {
            emitLog(text, level: level, file: f, function: fn, line: l)
        }
    } else {
        // 后台线程：异步转发到主线程
        Task { @MainActor in
            emitLog(text, level: level, file: f, function: fn, line: l)
        }
    }
}

// MARK: - 内部统一写入口

@MainActor
private func emitLog(_ message: Any,
                     level: LogLevel,
                     file: String,
                     function: String,
                     line: Int) {
    let fileName = (file as NSString).lastPathComponent
    let timestamp = DateFormatters.logTime.string(from: Date())
    let formatted = "[\(timestamp)] \(level.tag) [\(fileName):\(line)] \(function) -> \(message)"

    let manager = LogManager.shared
    if manager.consoleEnabled {
        print(formatted)
    }
    manager.write(formatted)
}

// MARK: - UI 状态

@MainActor
@Observable
final class LogManager {
    static let shared = LogManager()

    private(set) var entries: [LogEntry] = []

    var lineCount: Int { entries.count }

    var consoleEnabled: Bool = true
    var fileWriteEnabled: Bool = true

    @ObservationIgnored
    private let writer = LogFileWriter()

    @ObservationIgnored
    private var pendingWrites: [String] = []

    @ObservationIgnored
    private var flushTask: Task<Void, Never>?

    private init() {
        Task { await bootstrap() }
    }

    // MARK: - 启动

    private func bootstrap() async {
        await writer.setup()
        let content = await writer.readCurrentLog()
        entries = Self.parseLines(content)
    }

    // MARK: - 写入（批量缓冲）

    func write(_ message: String) {
        guard fileWriteEnabled else { return }

        entries.append(Self.parse(message, index: entries.count))
        pendingWrites.append(message)
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }

        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            await self?.flushNow()
        }
    }

    private func flushNow() async {
        flushTask = nil
        let batch = pendingWrites
        pendingWrites = []
        guard !batch.isEmpty else { return }
        await writer.appendBatch(batch)
    }

    // MARK: - 手动刷新

    func loadTodayLog() {
        Task {
            let content = await writer.readCurrentLog()
            entries = Self.parseLines(content)
        }
    }

    // MARK: - 清空

    func clearTodayLog() {
        entries = []
        pendingWrites = []
        flushTask?.cancel()
        flushTask = nil

        Task {
            await writer.clear()
            AppLogInfo("=== 日志已清空 ===")
        }
    }

    // MARK: - 解析

    private static func parseLines(_ content: String) -> [LogEntry] {
        guard !content.isEmpty else { return [] }
        var parts = content.components(separatedBy: "\n")
        if parts.last == "" { parts.removeLast() }
        return parts.enumerated().map { parse($0.element, index: $0.offset) }
    }

    private static func parse(_ line: String, index: Int) -> LogEntry {
        let (timestamp, rest) = splitTimestamp(line)
        let level = LogLevel.detect(in: line)
        let cleaned = stripLevelTag(from: rest, level: level)
        return LogEntry(
            id: index,
            timestamp: timestamp,
            rest: cleaned,
            level: level,
            raw: line
        )
    }

    private static func stripLevelTag(from text: String, level: LogLevel) -> String {
        let tag = level.tag
        guard text.hasPrefix(tag) else { return text }
        return String(text.dropFirst(tag.count))
            .trimmingCharacters(in: .whitespaces)
    }

    private static func splitTimestamp(_ line: String) -> (String?, String) {
        guard line.hasPrefix("[") else { return (nil, line) }
        guard let end = line.firstIndex(of: "]") else { return (nil, line) }

        let inside = String(line[line.index(after: line.startIndex)..<end])
        guard inside.contains(":") else { return (nil, line) }

        let rest = String(line[line.index(after: end)...])
            .trimmingCharacters(in: .whitespaces)
        return (inside, rest)
    }
}

// MARK: - 磁盘 I/O actor

actor LogFileWriter {
    private var fileSize: UInt64 = 0
    private var fileURL: URL?

    private let fileManager = FileManager.default

    private let maxFileSizeBytes: UInt64 = 10 * 1024 * 1024
    private let maxRetentionDays: Int = 7

    private var logsDirectory: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - 初始化

    func setup() {
        let fileName = "\(DateFormatters.dayOnly.string(from: Date())).log"
        let url = logsDirectory.appendingPathComponent(fileName)

        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
            fileSize = 0
        } else if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? UInt64 {
            fileSize = size
        }

        fileURL = url
        cleanOldLogs()
    }

    // MARK: - 批量追加

    func appendBatch(_ messages: [String]) {
        guard !messages.isEmpty else { return }

        let combined = messages.joined(separator: "\n") + "\n"
        let data = combined.data(using: .utf8) ?? Data()

        if fileSize + UInt64(data.count) >= maxFileSizeBytes {
            rollOver()
        }

        guard let url = fileURL,
              let handle = try? FileHandle(forWritingTo: url) else { return }

        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
        fileSize += UInt64(data.count)
    }

    // MARK: - 读取

    func readCurrentLog() -> String {
        guard let url = fileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return content
    }

    // MARK: - 清空

    func clear() {
        guard let url = fileURL else { return }
        try? "".write(to: url, atomically: true, encoding: .utf8)
        fileSize = 0
    }

    // MARK: - 文件轮转

    private func rollOver() {
        guard let url = fileURL else { return }

        let archiveName = "\(DateFormatters.archiveName.string(from: Date())).log"
        let archiveURL = logsDirectory.appendingPathComponent(archiveName)

        try? fileManager.moveItem(at: url, to: archiveURL)

        fileManager.createFile(atPath: url.path, contents: nil)
        fileSize = 0
    }

    // MARK: - 清理过期日志

    private func cleanOldLogs() {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -maxRetentionDays,
            to: Date()
        ) ?? Date()

        guard let files = try? fileManager.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        for fileURL in files where fileURL.pathExtension == "log" {
            if let attrs = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = attrs.contentModificationDate,
               modDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}
// MARK: - 日期格式化器

nonisolated enum DateFormatters {
    static let logTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static let dayOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let archiveName: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f
    }()
}
