//
//  WatchTheme.swift
//  Shared by the Amperly Watch App and the watch complication extension.
//
//  Compact, watchOS-safe brand theme (no UIKit; watchOS has no UIColor). Hex
//  values are identical to the app's brand tokens. No emoji; SF Symbols only.
//

import SwiftUI

extension Color {
    /// Build a Color from a 6-digit hex string. Falls back to clear if malformed.
    init(hex: String) {
        let raw = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        guard Scanner(string: raw).scanHexInt64(&v), raw.count == 6 else { self = .clear; return }
        self = Color(.sRGB,
                     red: Double((v & 0xFF0000) >> 16) / 255.0,
                     green: Double((v & 0x00FF00) >> 8) / 255.0,
                     blue: Double(v & 0x0000FF) / 255.0,
                     opacity: 1.0)
    }
}

enum WatchTheme {
    static let chargeLime = Color(hex: "#9CFF2E")
    static let chargeMint = Color(hex: "#34F5C5")
    static let chargeCyan = Color(hex: "#19C3FF")
    static let drainWarn = Color(hex: "#FF6B5A")
    static let track = Color(hex: "#283039")
    static let textHi = Color(hex: "#F4F7FA")
    static let textMid = Color(hex: "#A6B0BB")
    static let textLo = Color(hex: "#5C6772")
    static let lowThreshold: Double = 15

    static let energyGradient = LinearGradient(
        colors: [chargeLime, chargeMint, chargeCyan],
        startPoint: .bottomLeading, endPoint: .topTrailing
    )

    /// Energy gradient, or a flat drain-warn fill when the battery is critically low.
    static func fill(forLevel level: Double?) -> LinearGradient {
        if let level, level < lowThreshold {
            return LinearGradient(colors: [drainWarn, drainWarn], startPoint: .bottom, endPoint: .top)
        }
        return energyGradient
    }
}

enum WatchFormat {
    static func percent(_ v: Double?) -> String { v == nil ? "--" : "\(Int(v!.rounded()))%" }
    static func whole(_ v: Double?) -> String { v == nil ? "--" : "\(Int(v!.rounded()))" }
}

/// Compact vertical battery for the watch app and complications.
struct WatchBattery: View {
    let level: Double?
    var width: CGFloat = 22
    var height: CGFloat = 44

    private var clamped: Double { max(0, min(100, level ?? 0)) }

    var body: some View {
        let corner = width * 0.34
        VStack(spacing: 1.5) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(WatchTheme.track)
                .frame(width: width * 0.42, height: max(2, height * 0.05))
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(WatchTheme.track.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(WatchTheme.track, lineWidth: 1)
                    )
                GeometryReader { geo in
                    let inset: CGFloat = width * 0.16
                    let innerH = geo.size.height - inset * 2
                    let h = max(0, innerH * CGFloat(clamped / 100.0))
                    RoundedRectangle(cornerRadius: max(1.5, corner - inset), style: .continuous)
                        .fill(WatchTheme.fill(forLevel: level))
                        .frame(height: level == nil ? 0 : h)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(inset)
                }
            }
            .frame(width: width, height: height)
        }
    }
}
