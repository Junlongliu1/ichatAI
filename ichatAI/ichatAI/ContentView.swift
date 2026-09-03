//  ContentView.swift

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("首页", systemImage: "house.fill")
                    }
                    .tag(0)
                
                FilesTabView()
                    .tabItem {
                        Label("文件", systemImage: "folder.fill")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                    .tag(2)
            }
        }
    }
}
