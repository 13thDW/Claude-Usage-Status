// Models.swift

import SwiftUI

struct UsageData: Equatable {
    var sessionPercent: Double = 0
    var weeklyPercent:  Double = 0
    var resetsIn:       String = "—"
}

enum MenuBarIconStyle: String, CaseIterable {
    case full    = "Full ASCII"
    case compact = "Compact"
    case icon    = "Icon Only"

    func label(for pct: Double) -> String {
        switch self {
        case .full:
            let filled = Int((pct * 8).rounded())
            let bar    = String(repeating: "▓", count: filled)
                       + String(repeating: "░", count: 8 - filled)
            return "\(bar) \(Int(pct * 100))%"
        case .compact:
            return "\(Int(pct * 100))%"
        case .icon:
            // Larger filled-circle symbols, consistent visual weight
            switch pct {
            case ..<0.25: return "⊙"   // almost empty
            case ..<0.50: return "◑"   // half
            case ..<0.75: return "◕"   // three-quarters
            default:      return "●"   // full
            }
        }
    }
}

enum RingStyle: String, CaseIterable {
    case dynamic    = "Dynamic"
    case monochrome = "Monochrome"
}

// MARK: - Ring colour helper

extension Double {
    func ringColors(_ style: RingStyle) -> [Color] {
        switch style {
        case .monochrome:
            // Color.primary = white in dark mode, near-black in light mode
            // matches the system text colour automatically
            return [Color.primary, Color.primary.opacity(0.6)]
        case .dynamic:
            switch self {
            case ..<0.50: return [Color(hue: 0.38, saturation: 0.7, brightness: 0.85),
                                  Color(hue: 0.45, saturation: 0.6, brightness: 0.75)]
            case ..<0.80: return [Color(hue: 0.11, saturation: 0.9, brightness: 0.95),
                                  Color(hue: 0.07, saturation: 0.8, brightness: 0.90)]
            default:      return [Color(hue: 0.02, saturation: 0.9, brightness: 0.95),
                                  Color(hue: 0.97, saturation: 0.8, brightness: 0.85)]
            }
        }
    }
}
