// ToastCenter.swift
import SwiftUI
import Observation

// MARK: - 全局 Toast 中心
@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()

    private(set) var message: String?

    @ObservationIgnored
    private var task: Task<Void, Never>?

    private init() {}

    /// 显示一条 Toast，默认 1.5 秒后自动消失
    func show(_ text: String, duration: Duration = .seconds(1.5)) {
        task?.cancel()
        message = text
        task = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }

    func dismiss() {
        task?.cancel()
        task = nil
        message = nil
    }
}

// MARK: - 顶层覆盖视图（挂在 ContentView / HomeView 上）
struct ToastOverlay: View {
    private let center = ToastCenter.shared

    var body: some View {
        Group {
            if let msg = center.message {
                ToastView(message: msg)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: center.message)
        .allowsHitTesting(false)
    }
}

// MARK: - 预览
#Preview {
    VStack {
        Button("显示 Toast") {
            ToastCenter.shared.show("已保存到文件")
        }
    }
    .overlay(alignment: .top) {
        ToastOverlay()
    }
}
