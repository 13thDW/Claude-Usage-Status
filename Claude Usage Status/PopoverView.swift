// PopoverView.swift

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Popover
// ═══════════════════════════════════════════════════════════════

struct PopoverView: View {

    @EnvironmentObject private var state: AppState
    @AppStorage("ringStyle") private var ringStyle = RingStyle.dynamic

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().opacity(0.4)

                Group {
                    if state.isLoggedIn {
                        usageSection
                    } else {
                        loginSection
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state.isLoggedIn)

                if let err = state.errorMessage {
                    errorBanner(err)
                }

                Divider().opacity(0.4)
                footerBar
            }
        }
        .frame(width: 288)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                state.fetchUsage()
            }
        }
    }

    // ── Header ────────────────────────────────────────────────

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Text("Claude Usage")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if state.isLoading {
                ProgressView().scaleEffect(0.5).frame(width: 16, height: 16)
            }
            // Gear → Settings.
            // SettingsLink is the only reliable way to open the Settings scene
            // from a MenuBarExtra. The simultaneousGesture then forces the
            // window to front with a delay (window may not exist yet on first open).
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                // Retry a few times — window may not exist yet on first tap
                for delay in [0.15, 0.35, 0.6] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        NSApp.activate(ignoringOtherApps: true)
                        let win = NSApp.windows.first { w in
                            w.canBecomeKey
                            && !w.title.isEmpty
                            && w.title != "Sign in to Claude"
                        }
                        win?.makeKeyAndOrderFront(nil)
                        win?.orderFrontRegardless()
                    }
                }
            })
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // ── Usage section ─────────────────────────────────────────

    private var usageSection: some View {
        VStack(spacing: 18) {
            HStack(spacing: 0) {
                FitnessRing(label: "SESSION", sublabel: "5-hour window",
                            percent: state.usage.sessionPercent, style: ringStyle)
                    .frame(maxWidth: .infinity)

                Rectangle().fill(.primary.opacity(0.08)).frame(width: 1, height: 90)

                FitnessRing(label: "WEEKLY", sublabel: "7-day window",
                            percent: state.usage.weeklyPercent, style: ringStyle)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 5) {
                Image(systemName: "arrow.clockwise").font(.caption2).foregroundStyle(.tertiary)
                Text("Resets in").font(.caption).foregroundStyle(.tertiary)
                Text(state.usage.resetsIn).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // ── Login section ─────────────────────────────────────────

    private var loginSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 32)).foregroundStyle(.secondary).padding(.top, 8)
            Text("Not signed in").font(.callout.weight(.semibold))
            Text("Sign in to connect your Claude account.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Sign In to Claude…") { state.showLogin() }
                .buttonStyle(.borderedProminent).controlSize(.regular).tint(.indigo)
                .padding(.bottom, 10)
        }
        .padding(16).frame(maxWidth: .infinity)
    }

    // ── Error banner ──────────────────────────────────────────

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").font(.caption2)
            Text(msg).font(.caption2).lineLimit(2)
        }
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 7)
        .background(.orange.opacity(0.12))
    }

    // ── Footer ────────────────────────────────────────────────

    private var footerBar: some View {
        HStack {
            Button {
                DispatchQueue.main.async { state.fetchUsage() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise").font(.caption)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)

            Spacer()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - FitnessRing
// ═══════════════════════════════════════════════════════════════

private struct FitnessRing: View {

    let label:    String
    let sublabel: String
    let percent:  Double
    let style:    RingStyle

    private let diameter:  CGFloat = 96
    private let lineWidth: CGFloat = 9

    private var gradient: AngularGradient {
        let colors = percent.ringColors(style)
        return AngularGradient(
            gradient: Gradient(colors: colors + [colors.first!]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle:   .degrees(270)
        )
    }

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: percent)
                    .stroke(gradient,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: percent)

                // glowTip — disabled (position needs calibration)
                // glowTip

                VStack(spacing: 1) {
                    Text("\(Int(percent * 100))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: percent)
                    Text("%")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: diameter, height: diameter)

            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded)).kerning(0.8)
                Text(sublabel)
                    .font(.system(size: 8, design: .rounded)).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var glowTip: some View {
        if percent > 0.02 {
            let angle    = Angle.degrees(-90 + percent * 360)
            let r        = (diameter - lineWidth) / 2
            let tx       = cos(angle.radians) * r
            let ty       = sin(angle.radians) * r
            let tipColor = percent.ringColors(style).last ?? .primary

            // Soft glow behind
            Circle()
                .fill(tipColor.opacity(0.4))
                .frame(width: lineWidth + 6, height: lineWidth + 6)
                .blur(radius: 2)
                .offset(x: tx, y: ty)

            // Bright core dot, sits exactly on the arc center line
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: lineWidth * 0.55, height: lineWidth * 0.55)
                .offset(x: tx, y: ty)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Previews
// ═══════════════════════════════════════════════════════════════

#Preview("Logged in") {
    let s = AppState()
    s.usage = UsageData(sessionPercent: 0.58, weeklyPercent: 0.49, resetsIn: "2h 14m")
    s.isLoggedIn = true; s.orgID = "abc123"
    return PopoverView().environmentObject(s)
}
#Preview("Not signed in") { PopoverView().environmentObject(AppState()) }
