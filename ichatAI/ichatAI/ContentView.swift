// ContentView.swift
import SwiftUI

struct ContentView: View {
    private let themeManager = ThemeManager.shared

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .overlay(alignment: .top) {
            ToastOverlay()
        }
        .onAppear {
            themeManager.apply(animated: false)
        }
    }
}
