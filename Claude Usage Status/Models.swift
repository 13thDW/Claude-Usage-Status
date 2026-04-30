// Models.swift

import SwiftUI
import AppKit

struct UsageData: Equatable {
    var sessionPercent: Double = 0
    var weeklyPercent:  Double = 0
    var resetsIn:       String = "—"
}

enum MenuBarIconStyle: String, CaseIterable {
    case full    = "Full ASCII"
    case compact = "Compact"
    case icon    = "Icon Only"

    /// Preview text for the Settings picker.
    func previewLabel(for pct: Double) -> String {
        switch self {
        case .full:
            let filled = Int((pct * 8).rounded())
            return String(repeating: "▓", count: filled)
                 + String(repeating: "░", count: 8 - filled)
                 + " \(Int(pct * 100))%"
        case .compact:
            return "\(Int(pct * 100))%"
        case .icon:
            return "◕"
        }
    }

    /// Render the menu bar item as an NSImage (template).
    /// Using NSImage for ALL styles avoids the SwiftUI MenuBarExtra
    /// duplication bug that occurs when switching between Text and Image
    /// view types via a conditional.
    func menuBarImage(for pct: Double) -> NSImage {
        switch self {
        case .full:
            let filled = Int((pct * 8).rounded())
            let bar    = String(repeating: "▓", count: filled)
                       + String(repeating: "░", count: 8 - filled)
            let text   = "\(bar) \(Int(pct * 100))%"
            return Self.textToImage(text, font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium))

        case .compact:
            let text = "\(Int(pct * 100))%"
            return Self.textToImage(text, font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium))

        case .icon:
            return MenuBarIcon.nsImage(percent: pct, size: 16)
        }
    }

    /// Render a string as a template NSImage for the menu bar.
    private static func textToImage(_ string: String, font: NSFont) -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black  // template mode will tint it
        ]
        let size = (string as NSString).size(withAttributes: attrs)
        let img = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)),
                          flipped: false) { rect in
            (string as NSString).draw(at: .zero, withAttributes: attrs)
            return true
        }
        img.isTemplate = true
        return img
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

// ═══════════════════════════════════════════════════════════════
// MARK: - MenuBarIcon (dynamic ring as NSImage)
// ═══════════════════════════════════════════════════════════════

enum MenuBarIcon {

    static func nsImage(percent: Double, size: CGFloat = 16) -> NSImage {
        let lineWidth: CGFloat = 2.4
        let inset = lineWidth / 2 + 0.5
        let rect  = NSRect(x: 0, y: 0, width: size, height: size)

        let img = NSImage(size: rect.size, flipped: false) { drawRect in
            let center = CGPoint(x: drawRect.midX, y: drawRect.midY)
            let radius = drawRect.width / 2 - inset

            // Track ring
            let trackPath = NSBezierPath()
            trackPath.appendArc(withCenter: center, radius: radius,
                                startAngle: 0, endAngle: 360)
            trackPath.lineWidth = lineWidth
            trackPath.lineCapStyle = .round
            NSColor(white: 0, alpha: 0.25).setStroke()
            trackPath.stroke()

            // Fill arc
            if percent > 0.005 {
                let fillPath = NSBezierPath()
                fillPath.appendArc(withCenter: center, radius: radius,
                                   startAngle: 90,
                                   endAngle: 90 - CGFloat(percent) * 360,
                                   clockwise: true)
                fillPath.lineWidth = lineWidth
                fillPath.lineCapStyle = .round
                NSColor(white: 0, alpha: 1.0).setStroke()
                fillPath.stroke()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
