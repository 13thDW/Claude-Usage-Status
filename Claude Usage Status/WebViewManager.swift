// WebViewManager.swift

import AppKit
import WebKit

@MainActor
final class WebViewManager: NSObject {

    // ── Callbacks ─────────────────────────────────────────────
    var onUsageUpdate:   ((UsageData) -> Void)?
    var onLoginDetected: (() -> Void)?
    var onError:         ((String) -> Void)?

    // ── Internals ─────────────────────────────────────────────
    private let webView: WKWebView
    private var loginWindow: NSWindow?
    private var pendingURL: String? = nil
    private var cookiePollTimer: Timer?   // polls for lastActiveOrg while login window is open

    // ── Init ──────────────────────────────────────────────────

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.applicationNameForUserAgent = "Version/17.4 Safari/605.1.15"

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) " +
            "Version/17.4 Safari/605.1.15"

        super.init()
        webView.navigationDelegate = self

        // Pre-warm session
        webView.load(URLRequest(url: URL(string: "https://claude.ai")!,
                                cachePolicy: .returnCacheDataElseLoad))
    }

    // ── Login window ──────────────────────────────────────────

    func showLoginWindow() {
        if loginWindow == nil {
            let container = NSView()
            webView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(webView)
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                webView.topAnchor.constraint(equalTo: container.topAnchor),
                webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered, defer: false
            )
            win.title = "Sign in to Claude"
            win.contentView = container
            win.center()
            win.delegate = self
            loginWindow = win
        }

        // Always reload so the page is fresh (especially after logout)
        webView.load(URLRequest(url: URL(string: "https://claude.ai")!))

        loginWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Start polling for the lastActiveOrg cookie.
        // The cookie is written by JS after page init — we can't rely on
        // navigation events to know exactly when it appears.
        startCookiePolling()
    }

    private func dismissLoginWindow() {
        stopCookiePolling()
        webView.removeFromSuperview()
        loginWindow?.orderOut(nil)
        loginWindow = nil
    }

    // ── Cookie polling ────────────────────────────────────────
    //
    // Poll every 1.5 s while the login window is open.
    // As soon as lastActiveOrg appears in the cookie store, dismiss the
    // window and fire onLoginDetected — no matter when the JS wrote it.

    private func startCookiePolling() {
        stopCookiePolling()
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkForOrgCookie()
        }
        RunLoop.main.add(t, forMode: .common)
        cookiePollTimer = t
    }

    private func stopCookiePolling() {
        cookiePollTimer?.invalidate()
        cookiePollTimer = nil
    }

    private func checkForOrgCookie() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            // Only act if the login window is still open
            guard self.loginWindow != nil else {
                self.stopCookiePolling()
                return
            }
            if cookies.contains(where: { $0.name == "lastActiveOrg" }) {
                self.dismissLoginWindow()
                self.onLoginDetected?()
            }
        }
    }

    // ── Public reload (called after logout) ───────────────────

    func reloadHome() {
        webView.load(URLRequest(url: URL(string: "https://claude.ai")!))
    }

    // ── Fetch entry point ─────────────────────────────────────

    func fetchUsageData(from usageURL: String) {
        guard webView.url?.host?.contains("claude.ai") == true else {
            pendingURL = usageURL
            webView.load(URLRequest(url: URL(string: "https://claude.ai")!,
                                    cachePolicy: .returnCacheDataElseLoad))
            return
        }
        runFetch(usageURL: usageURL)
    }

    // ── JS Fetch (callAsyncJavaScript + async fetch) ──────────

    private func runFetch(usageURL: String) {
        let lines = [
            "const res = await fetch('\(usageURL)', {",
            "    credentials: 'include',",
            "    headers: { 'Accept': 'application/json' }",
            "});",
            "if (!res.ok) { return JSON.stringify({ __err: 'HTTP ' + res.status }); }",
            "const body = await res.json();",
            "return JSON.stringify(body);",
        ]
        webView.callAsyncJavaScript(
            lines.joined(separator: "\n"),
            arguments: [:],
            in: nil,
            in: .defaultClient
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let err): self.onError?("JS: \(err.localizedDescription)")
            case .success(let val): self.handleResult(val)
            }
        }
    }

    // ── Result handling ───────────────────────────────────────

    private func handleResult(_ value: Any?) {
        guard let raw = value as? String else {
            onError?("No data — are you logged in?"); return
        }
        guard let data = raw.data(using: .utf8) else {
            onError?("Could not encode response"); return
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = obj["__err"] as? String {
            onError?(err); return
        }
        parseResponse(data)
    }

    // ── JSON → UsageData ──────────────────────────────────────

    private struct Bucket: Decodable {
        let utilization: Double
        let resetsAt: String?
        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    private struct RateLimitResponse: Decodable {
        let fiveHour: Bucket?
        let sevenDay: Bucket?
        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    private func parseResponse(_ data: Data) {
        guard let r = try? JSONDecoder().decode(RateLimitResponse.self, from: data) else {
            onError?("Could not decode usage JSON"); return
        }
        let sessionPct = (r.fiveHour?.utilization ?? 0) / 100.0
        let weeklyPct  = (r.sevenDay?.utilization  ?? 0) / 100.0
        let resetsAt   = r.fiveHour?.resetsAt ?? r.sevenDay?.resetsAt
        let resetsIn   = resetsAt.flatMap(Self.countdown) ?? "—"
        onUsageUpdate?(UsageData(
            sessionPercent: min(sessionPct, 1),
            weeklyPercent:  min(weeklyPct,  1),
            resetsIn:       resetsIn
        ))
    }

    private static func countdown(_ iso: String) -> String? {
        let f: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        guard let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        else { return nil }
        let s = date.timeIntervalSinceNow
        guard s > 0 else { return "soon" }
        let h = Int(s / 3600), m = Int(s.truncatingRemainder(dividingBy: 3600) / 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// ── WKNavigationDelegate ──────────────────────────────────────

extension WebViewManager: WKNavigationDelegate {

    nonisolated func webView(_ webView: WKWebView,
                             didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            guard let self, let url = webView.url else { return }
            let onClaude = url.host?.contains("claude.ai") == true
            let atLogin  = url.path.contains("login")

            // Deferred fetch after context reload
            if onClaude && !atLogin, let pending = self.pendingURL {
                self.pendingURL = nil
                self.runFetch(usageURL: pending)
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFail navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor [weak self] in
            self?.onError?("Navigation: \(error.localizedDescription)")
        }
    }
}

// ── NSWindowDelegate ──────────────────────────────────────────

extension WebViewManager: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.stopCookiePolling()
            self.webView.removeFromSuperview()
            self.loginWindow = nil
        }
    }
}
