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
            // SettingsLink opens the window; simultaneousGesture brings it
            // to front even if it is buried behind other windows.
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows
                        .first { $0.title == "Settings" }?
                        .makeKeyAndOrderFront(nil)
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

                glowTip

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
        if percent > 0.01 {
            let angle    = Angle.degrees(-90 + percent * 360)
            let radius   = (diameter - lineWidth) / 2
            let tipColor = percent.ringColors(style).last ?? .accentColor
            Circle()
                .fill(tipColor)
                .frame(width: lineWidth, height: lineWidth)
                .shadow(color: tipColor.opacity(0.8), radius: 4)
                .offset(x: cos(angle.radians) * radius,
                        y: sin(angle.radians) * radius)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: percent)
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
