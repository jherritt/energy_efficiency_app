import SwiftUI

// MARK: - Hex initializer

extension Color {
    /// Build a Color from a 0xRRGGBB integer. Alpha is always fully opaque.
    init(hex: UInt) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

// MARK: - Brand palette

extension Color {
    /// App background. Adapts to light/dark: deep ink in dark, soft white-blue in light.
    static let inkBase = Color.dynamic(dark: 0x06080B, light: 0xF4F7FA)

    /// Card / tile surface. A touch lighter than the base in dark; soft white in light.
    static let inkElev = Color.dynamic(dark: 0x0E141A, light: 0xFFFFFF)

    /// Battery shell and empty progress track.
    static let track = Color.dynamic(dark: 0x283039, light: 0xDCE3EB)

    // Energy accents (fixed across appearances so the gradient stays vivid).
    static let chargeLime = Color(hex: 0x9CFF2E)
    static let chargeMint = Color(hex: 0x34F5C5)
    static let chargeCyan = Color(hex: 0x19C3FF)

    /// Low-battery / depleted state ONLY.
    static let drainWarn = Color(hex: 0xFF6B5A)

    /// Primary text. Near-white in dark, deep ink in light.
    static let textHi = Color.dynamic(dark: 0xF4F7FA, light: 0x0E141A)

    /// Secondary text.
    static let textMid = Color.dynamic(dark: 0xA6B0BB, light: 0x5C6772)

    /// Tertiary / eyebrow text.
    static let textLo = Color.dynamic(dark: 0x5C6772, light: 0x8C97A2)
}

// MARK: - Dynamic (light/dark) helper

private extension Color {
    /// A color that resolves to one hex in dark mode and another in light mode.
    /// Falls back to the dark value on platforms without a trait environment.
    static func dynamic(dark: UInt, light: UInt) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .light
                ? UIColor(rgb: light)
                : UIColor(rgb: dark)
        })
        #else
        return Color(hex: dark)
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
#endif
