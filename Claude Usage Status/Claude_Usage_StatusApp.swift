// ClaudeUsageStatusApp.swift
// Info.plist: LSUIElement = YES

import SwiftUI

@main
struct ClaudeUsageStatusApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {

        MenuBarExtra {
            PopoverView()
                .environmentObject(appState)
        } label: {
            // All styles render as NSImage (template) to avoid the SwiftUI
            // MenuBarExtra bug where switching between Text and Image view
            // types via conditional causes duplication artifacts.
            Image(nsImage: appState.iconStyle.menuBarImage(for: appState.usage.sessionPercent))
                .accessibilityLabel("Claude usage \(Int(appState.usage.sessionPercent * 100))%")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
