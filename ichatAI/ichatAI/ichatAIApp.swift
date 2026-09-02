//
//  ichatAIApp.swift
//  ichatAI
//
//  Created by 龙 on 2026/9/2.
//

import SwiftUI
import SwiftData

@main
struct ichatAIApp: App {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
