// Color+Hex.swift
// Color 便利构造：从 UInt32 十六进制生成颜色
import SwiftUI

extension Color {
    /// 用法：`Color(hex: 0x10A37F)` 或 `Color(hex: 0x10A37F, alpha: 0.5)`
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xFF) / 255.0,
            green:   Double((hex >> 8)  & 0xFF) / 255.0,
            blue:    Double( hex        & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
