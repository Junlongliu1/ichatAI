import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("外观") {
                    Toggle(isOn: $isDarkMode) {
                        Label("暗黑模式", systemImage: "moon.fill")
                    }
                }
                
                Section("关于 iChatAI") { // ✅ 更新 Section 标题
                    HStack {
                        Text("版本号")
                        Spacer()
                        Text(AppInfo.version)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("iChatAI 设置") // ✅ 更新导航栏标题
        }
    }
}
