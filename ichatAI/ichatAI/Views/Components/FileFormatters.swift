// FileFormatters.swift
// 文件相关的共享格式化器
// 说明：ByteCountFormatter / RelativeDateTimeFormatter 的构造有开销，
//      且在列表滚动时会高频调用，因此全局共享单例。

import Foundation

enum FileFormatters {

    /// 文件大小格式化：自动选用 KB / MB / GB
    static let size: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f
    }()

    /// 相对时间格式化：中文、缩写风格（如 "3 分钟前"）
    static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.unitsStyle = .abbreviated
        return f
    }()
}
