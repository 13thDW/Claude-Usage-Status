// SettingsView.swift

import SwiftUI
import ServiceManagement

struct SettingsView: View {

    @EnvironmentObject private var state: AppState

    var body: some View {
        TabView {
            GeneralTab()
                .environmentObject(state)
                .tabItem { Label("General", systemImage: "gearshape") }

            AppearanceTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
        .frame(width: 420)
        .fixedSize()
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - General tab
// ═══════════════════════════════════════════════════════════════

private struct GeneralTab: View {

    @EnvironmentObject private var state: AppState
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var showLogoutConfirm = false

    var body: some View {
        Form {

            // ── Startup ───────────────────────────────────────
            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _ in state.syncLaunchAtLogin() }
            }

            // ── Account ───────────────────────────────────────
            Section("Account") {
                if state.isLoggedIn, state.orgID != nil {
                    LabeledContent("Status") {
                        Text("Signed in").foregroundStyle(.green)
                    }
                    LabeledContent("Org ID") {
                        Text(state.maskedOrgID)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    // Full-width Log Out button
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundStyle(.red)
                    .confirmationDialog(
                        "Log out of Claude?",
                        isPresented: $showLogoutConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Log Out", role: .destructive) { state.logOut() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will clear all cookies and session data.")
                    }

                } else {
                    LabeledContent("Status") {
                        Text("Not signed in").foregroundStyle(.secondary)
                    }
                    Button("Sign In…") { state.showLogin() }
                }
            }

            // ── Help ──────────────────────────────────────────
            Section("Help") {
                Link(destination: URL(string: "https://claude.ai")!) {
                    Label("Open Claude.ai", systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://support.anthropic.com")!) {
                    Label("Anthropic Support", systemImage: "questionmark.circle")
                }

                // Left-aligned description — Apple's HIG: descriptive text
                // under a section header should align with the leading edge.
                VStack(alignment: .leading, spacing: 4) {
                    Text("How it works")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text("Reads rate-limit data from your active Claude session via a hidden WebView. No API key required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Appearance tab
// ═══════════════════════════════════════════════════════════════

private struct AppearanceTab: View {

    @AppStorage("menuBarIconStyle") private var iconStyle = MenuBarIconStyle.full
    @AppStorage("ringStyle")        private var ringStyle = RingStyle.dynamic

    var body: some View {
        Form {

            // ── Menu bar icon ─────────────────────────────────
            Section("Menu Bar Icon") {
                Picker("Style", selection: $iconStyle) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { s in
                        HStack {
                            Text(s.rawValue)
                            Spacer()
                            // Preview at a legible size
                            Text(s.label(for: 0.44))
                                .font(s == .icon
                                      ? .system(size: 15, weight: .regular)   // bigger for symbols
                                      : .system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .tag(s)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            // ── Progress rings ────────────────────────────────
            Section("Progress Rings") {
                Picker("Colour", selection: $ringStyle) {
                    ForEach(RingStyle.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.inline)

                if ringStyle == .dynamic {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("0 – 49 %     Green",  systemImage: "circle.fill").foregroundStyle(.green)
                        Label("50 – 79 %   Orange", systemImage: "circle.fill").foregroundStyle(.orange)
                        Label("80 – 100 % Red",     systemImage: "circle.fill").foregroundStyle(.red)
                    }
                    .font(.caption)
                } else {
                    Text("Rings match the system text colour — white in Dark Mode, dark in Light Mode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Preview
// ═══════════════════════════════════════════════════════════════

#Preview {
    let s = AppState()
    s.isLoggedIn = true
    s.orgID = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
    return SettingsView().environmentObject(s)
}
