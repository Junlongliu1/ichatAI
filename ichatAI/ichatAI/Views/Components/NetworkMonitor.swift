// NetworkMonitor.swift
import SwiftUI
import Network
import Observation

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isOnline: Bool = true

    @ObservationIgnored
    private let monitor = NWPathMonitor()

    @ObservationIgnored
    private let queue = DispatchQueue(label: "ichatAI.networkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isOnline != online {
                    self.isOnline = online
                    AppLogInfo("[Network] 状态: \(online ? "在线" : "离线")")
                }
            }
        }
        monitor.start(queue: queue)
    }
}

// MARK: - 离线横幅
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .medium))
            Text("网络未连接")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.orange.gradient)
    }
}
