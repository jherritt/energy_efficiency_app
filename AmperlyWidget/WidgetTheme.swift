//
//  WidgetTheme.swift
//  AmperlyWidget
//
//  A compact, self-contained copy of Amperly's brand theme for the widget
//  extension. The widget target does not share the app's Theme files, so the
//  brand tokens (hex values), the energy gradient, and a small reusable battery
//  view live here. Hex values are identical to the app's brand tokens.
//
//  No emoji anywhere. Glyphs come from SF Symbols only.
//

import SwiftUI
import UIKit

// MARK: - Hex color helper

extension Color {
    /// Build a Color from a hex string such as "#9CFF2E" or "9CFF2E".
    /// Falls back to clear on a malformed string rather than crashing.
    init(hex: String) {
        let raw = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        guard Scanner(string: raw).scanHexInt64(&value) else {
            self = .clear
            return
        }
        let r, g, b, a: Double
        switch raw.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8) / 255.0
            a = Double(value & 0x000000FF) / 255.0
        default:
            self = .clear
            return
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Brand tokens

/// Amperly's brand palette. Kept byte-identical to the app's Theme so the
/// widget and the app render the same "electric" look.
enum WidgetTheme {

    // Surfaces
    static let inkBase = Color(hex: "#06080B")   // dark background
    static let inkBaseLight = Color(hex: "#F4F7FA") // light-mode background
    static let inkElev = Color(hex: "#0E141A")   // cards / tiles
    static let track = Color(hex: "#283039")     // battery shell + empty track

    // Energy accents
    static let chargeLime = Color(hex: "#9CFF2E")
    static let chargeMint = Color(hex: "#34F5C5") // primary accent
    static let chargeCyan = Color(hex: "#19C3FF")

    // Low / depleted ONLY
    static let drainWarn = Color(hex: "#FF6B5A")

    // Text
    static let textHi = Color(hex: "#F4F7FA")
    static let textMid = Color(hex: "#A6B0BB")
    static let textLo = Color(hex: "#5C6772")

    // Spacing (mirrors the app's DS.Space 4pt grid without importing it)
    static let spaceXXS: CGFloat = 4
    static let spaceXS: CGFloat = 8
    static let spaceSM: CGFloat = 12
    static let spaceMD: CGFloat = 16

    /// Subtle top-lit hairline used on every card edge in the app: bright at
    /// the top, fading out toward the bottom. Reads as machined, not drawn.
    /// Copied verbatim from DS.hairline.
    static let hairline = LinearGradient(
        colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
        startPoint: .top, endPoint: .bottom
    )

    /// Ambient widget surface, copied verbatim from the app's
    /// DS.AmbientBackground: near-black with a whisper of mint falloff at the
    /// top, so the widget and the app read as one continuous material.
    static var ambientBackground: some View {
        ZStack {
            inkBase
            RadialGradient(
                colors: [chargeMint.opacity(0.055), .clear],
                center: .init(x: 0.5, y: -0.12),
                startRadius: 0, endRadius: 420
            )
        }
    }

    /// The signature energy gradient: lime -> mint -> cyan, bottom-leading to
    /// top-trailing. Paints the battery fill and the hero number.
    static let energyGradient = LinearGradient(
        colors: [chargeLime, chargeMint, chargeCyan],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    /// Crossfade target when the battery is critically low.
    static let lowBatteryThreshold: Double = 15

    /// The fill style for a battery at a given level: the energy gradient,
    /// crossfading toward the drain-warn red as level drops below the threshold.
    static func fillGradient(forLevel level: Double?) -> LinearGradient {
        guard let level, level < lowBatteryThreshold else { return energyGradient }
        // Below threshold: blend toward drainWarn the lower we go (0 == full warn).
        let t = max(0, min(1, level / lowBatteryThreshold)) // 1 at threshold, 0 empty
        let warn = drainWarn
        return LinearGradient(
            colors: [
                warn.mix(with: chargeLime, by: t),
                warn.mix(with: chargeMint, by: t),
                warn.mix(with: chargeCyan, by: t)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
}

// MARK: - Color blending (iOS 17 compatible)

extension Color {
    /// Linearly blend two colors. `fraction` is the weight of `other`
    /// (0 == self, 1 == other). Implemented manually for iOS 17 support.
    func mix(with other: Color, by fraction: Double) -> Color {
        let f = max(0, min(1, fraction))
        let a = UIColor(self)
        let b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            .sRGB,
            red: Double(ar + (br - ar) * f),
            green: Double(ag + (bg - ag) * f),
            blue: Double(ab + (bb - ab) * f),
            opacity: Double(aa + (ba - aa) * f)
        )
    }
}

// MARK: - Battery view

/// A HORIZONTAL battery used by the home widget families. Renders a rounded
/// shell (the `track`), a gradient fill anchored LEADING that grows left to
/// right with `level` (0...100), and a small terminal cap nub on the RIGHT.
/// When `level` is nil (unauthorized), shows an empty shell.
struct WidgetBattery: View {
    /// 0...100, or nil for "--" / unauthorized.
    let level: Double?
    /// Total width of the battery, INCLUDING the terminal cap on the right.
    var width: CGFloat = 84
    /// Height of the battery body (the cap is shorter, centered vertically).
    var height: CGFloat = 20

    private var clamped: Double { max(0, min(100, level ?? 0)) }
    private var isLow: Bool { (level ?? 100) < WidgetTheme.lowBatteryThreshold }

    var body: some View {
        let corner = height * 0.34
        let capWidth = max(3, height * 0.16)
        let capHeight = max(4, height * 0.44)
        let capSpacing = capWidth * 0.6
        let bodyWidth = max(0, width - capWidth - capSpacing)
        let inset: CGFloat = height * 0.16

        HStack(spacing: capSpacing) {
            // Body
            ZStack(alignment: .leading) {
                // Empty track / shell
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(WidgetTheme.track.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(WidgetTheme.hairline, lineWidth: 1)
                    )

                // Fill grows left -> right
                GeometryReader { geo in
                    let innerWidth = geo.size.width - inset * 2
                    let fillWidth = max(0, innerWidth * CGFloat(clamped / 100.0))
                    RoundedRectangle(cornerRadius: max(2, corner - inset), style: .continuous)
                        .fill(WidgetTheme.fillGradient(forLevel: level))
                        .frame(width: level == nil ? 0 : fillWidth)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(inset)
                        // Glow scales with the bar so the smallest canvas stays
                        // lit rather than neon: radius tracks height, opacity
                        // eases up only at the tallest (large-family) size.
                        .shadow(color: (isLow ? WidgetTheme.drainWarn : WidgetTheme.chargeMint)
                            .opacity(level == nil ? 0 : (height >= 22 ? 0.5 : 0.35)),
                                radius: height * 0.2, x: 0, y: 0)
                }
            }
            .frame(width: bodyWidth, height: height)

            // Terminal cap nub on the RIGHT
            RoundedRectangle(cornerRadius: capWidth * 0.6, style: .continuous)
                .fill(WidgetTheme.track)
                .frame(width: capWidth, height: capHeight)
        }
        .frame(width: width, height: height)
        .accessibilityElement()
        .accessibilityLabel("Battery")
        .accessibilityValue(level == nil ? "No data" : "\(Int(clamped.rounded())) percent")
    }
}

// MARK: - Shared formatting

enum WidgetFormat {
    /// Render an optional 0...100 metric as a whole-number percent, or "--".
    static func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    /// Render an optional 0...100 metric as a whole number, or "--".
    static func whole(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))"
    }
}

// MARK: - Eyebrow label

/// ALL CAPS, bold, wide-tracked eyebrow text in the low-emphasis text color.
struct WidgetEyebrow: View {
    let text: String
    var color: Color = WidgetTheme.textLo

    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption2, design: .default).weight(.bold))
            .tracking(3)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
