//  Claude_Usage_StatusApp.swift
//  Claude Usage Status
//
//  Created by Whaler on 4/26/26.
//

import SwiftUI

@main
struct Claude_Usage_StatusApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {

        // ── Menu bar extra ────────────────────────────────────
        MenuBarExtra {
            PopoverView()
                .environmentObject(appState)
        } label: {
            Text(appState.menuBarLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .menuBarExtraStyle(.window)

        // ── Settings window ───────────────────────────────────
        // Opened from the popover via:
        //   NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

