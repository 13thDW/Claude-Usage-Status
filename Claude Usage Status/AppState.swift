// AppState.swift

import SwiftUI
import WebKit
import ServiceManagement
import Combine

final class AppState: ObservableObject {
 
    // ── Published UI state ────────────────────────────────────
    @Published var usage           = UsageData()
    @Published var isLoggedIn      = false
    @Published var isLoading       = false
    @Published var errorMessage: String? = nil
    @Published var orgID: String?  = nil   // extracted from lastActiveOrg cookie
 
    // ── AppStorage settings ───────────────────────────────────
    @AppStorage("launchAtLogin")   var launchAtLogin   = false
    @AppStorage("menuBarIconStyle") var iconStyle      = MenuBarIconStyle.full
    @AppStorage("ringStyle")        var ringStyle      = RingStyle.dynamic
 
    // ── Sub-systems ───────────────────────────────────────────
    let webViewManager = WebViewManager()
    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 300   // 5 min background poll
 
    // ── Computed ──────────────────────────────────────────────
    var menuBarLabel: String { iconStyle.label(for: usage.sessionPercent) }
 
    var maskedOrgID: String {
        guard let id = orgID, id.count > 12 else { return orgID ?? "—" }
        let prefix = id.prefix(6)
        let suffix = id.suffix(6)
        return "\(prefix)…\(suffix)"
    }
 
    // ─────────────────────────────────────────────────────────
    init() {
        webViewManager.onUsageUpdate = { [weak self] data in
            self?.usage        = data
            self?.isLoggedIn   = true
            self?.isLoading    = false
            self?.errorMessage = nil
        }
        webViewManager.onError = { [weak self] msg in
            self?.errorMessage = msg
            self?.isLoading    = false
        }
 
        // Defer startup past the first SwiftUI render pass
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startup()
        }
    }
 
    // ── Startup ───────────────────────────────────────────────
 
    private func startup() {
        syncLaunchAtLogin()
        extractOrgIDAndFetch()
        schedulePollTimer()
    }
 
    // ── Launch at login ───────────────────────────────────────
 
    func syncLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently ignore — user may have revoked permission
        }
    }
 
    // ── Cookie extraction → org ID ────────────────────────────
 
    func extractOrgIDAndFetch(retryCount: Int = 0) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            DispatchQueue.main.async {
                guard let self else { return }
                if let org = cookies.first(where: { $0.name == "lastActiveOrg" })?.value {
                    self.orgID      = org
                    self.isLoggedIn = true
                    self.fetchUsage()
                } else if retryCount < 5 {
                    // Cookie not written yet — retry with backoff
                    let delay = Double(retryCount + 1) * 1.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.extractOrgIDAndFetch(retryCount: retryCount + 1)
                    }
                } else {
                    self.isLoggedIn = false
                    self.orgID      = nil
                    self.errorMessage = "Could not find session cookie. Try logging in again."
                }
            }
        }
    }
 
    // ── Polling timer ─────────────────────────────────────────
 
    private func schedulePollTimer() {
        pollTimer?.invalidate()
        let t = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
        t.tolerance = 30
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }
 
    // ── Fetch ─────────────────────────────────────────────────
 
    func fetchUsage() {
        guard !isLoading, let orgID else { return }
        isLoading = true
        let url = "https://claude.ai/api/organizations/\(orgID)/usage"
        webViewManager.fetchUsageData(from: url)
    }
 
    // ── Auth ──────────────────────────────────────────────────
 
    func showLogin() {
        webViewManager.onLoginDetected = { [weak self] in
            self?.extractOrgIDAndFetch()
        }
        webViewManager.showLoginWindow()
    }
 
    func logOut() {
        pollTimer?.invalidate()
        pollTimer = nil
 
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.usage         = UsageData()
                self.isLoggedIn    = false
                self.orgID         = nil
                self.errorMessage  = nil
                self.schedulePollTimer()
                // Re-warm the WebView so the next login window is not blank
                self.webViewManager.reloadHome()
            }
        }
    }
}
