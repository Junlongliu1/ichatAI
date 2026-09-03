//  ichatAIApp.swift


import SwiftUI
import SwiftData

@main
struct ichatAIApp: App {
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(
                    AppTheme(rawValue: appThemeRaw) == .dark ? .dark :
                    AppTheme(rawValue: appThemeRaw) == .light ? .light : nil
                )
        }
    }
}
