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

// MARK: - Brand palette (dark-only)

// Amperly is a dark-only app. Every token is a fixed brand hex; there is no
// light-mode variant by design.
extension Color {
    /// App background. Deep ink.
    static let inkBase = Color(hex: 0x06080B)

    /// Card / tile surface. A touch lighter than the base.
    static let inkElev = Color(hex: 0x0E141A)

    /// Battery shell and empty progress track.
    static let track = Color(hex: 0x283039)

    // Energy accents.
    static let chargeLime = Color(hex: 0x9CFF2E)
    static let chargeMint = Color(hex: 0x34F5C5)
    static let chargeCyan = Color(hex: 0x19C3FF)

    /// Low-battery / depleted state ONLY.
    static let drainWarn = Color(hex: 0xFF6B5A)

    /// Primary text. Near-white.
    static let textHi = Color(hex: 0xF4F7FA)

    /// Secondary text.
    static let textMid = Color(hex: 0xA6B0BB)

    /// Tertiary / eyebrow text.
    static let textLo = Color(hex: 0x5C6772)
}
