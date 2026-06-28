import SwiftUI

/// Central, reusable styling for Amperly's "electric" look: the energy gradient,
/// battery fill (which crossfades to a warn color when low), the all-caps eyebrow
/// label style, and the hero number treatment.
enum AmperlyTheme {

    // MARK: Gradients

    /// The signature 3-stop energy gradient (lime -> mint -> cyan),
    /// painted bottom-leading to top-trailing.
    static let energyGradient = LinearGradient(
        colors: [.chargeLime, .chargeMint, .chargeCyan],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    /// Battery-fill gradient for a given level (0...100). Below `lowBatteryThreshold`
    /// the fill crossfades toward `drainWarn` so a depleting battery reads as urgent.
    static func batteryFill(forLevel level: Double) -> LinearGradient {
        let clamped = min(max(level, 0), 100)
        guard clamped < lowBatteryThreshold else { return energyGradient }

        // 0 at the threshold -> 1 at empty. The lower the battery, the warmer.
        let t = (lowBatteryThreshold - clamped) / lowBatteryThreshold
        let warn = Color.drainWarn
        return LinearGradient(
            colors: [
                Color.chargeLime.mixed(with: warn, amount: t),
                Color.chargeMint.mixed(with: warn, amount: t),
                Color.chargeCyan.mixed(with: warn, amount: t * 0.85)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    /// Battery level below which the fill warms toward `drainWarn`.
    static let lowBatteryThreshold: Double = 15

    // MARK: Glow

    /// Soft mint glow used behind the battery fill and hero number.
    static let glow = Color.chargeMint

    // MARK: - Eyebrow label modifier

    /// ALL-CAPS, bold, wide-tracked, low-contrast section label
    /// (e.g. "EFFICIENCY", "POINTS TODAY").
    struct Eyebrow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.caption, design: .default, weight: .bold))
                .textCase(.uppercase)
                .tracking(3)
                .foregroundStyle(Color.textLo)
        }
    }

    // MARK: - Hero number style

    /// Paints text with the energy gradient plus a soft glow, monospaced digits.
    /// Used for the big efficiency / battery numbers.
    struct HeroNumber: ViewModifier {
        var glowRadius: CGFloat = 18
        func body(content: Content) -> some View {
            content
                .font(.system(size: 96, weight: .heavy, design: .default))
                .monospacedDigit()
                .foregroundStyle(AmperlyTheme.energyGradient)
                .shadow(color: AmperlyTheme.glow.opacity(0.55), radius: glowRadius)
        }
    }
}

// MARK: - View conveniences

extension View {
    /// Apply the standard eyebrow (section label) treatment.
    func eyebrowStyle() -> some View { modifier(AmperlyTheme.Eyebrow()) }

    /// Apply the hero-number treatment (gradient fill + glow + heavy monospaced).
    func heroNumberStyle(glowRadius: CGFloat = 18) -> some View {
        modifier(AmperlyTheme.HeroNumber(glowRadius: glowRadius))
    }
}

// MARK: - Color mixing (for the low-battery crossfade)

private extension Color {
    /// Linear blend toward `other` by `amount` (0...1) in sRGB.
    func mixed(with other: Color, amount: Double) -> Color {
        #if canImport(UIKit)
        let a = UIColor(self)
        let b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let t = CGFloat(min(max(amount, 0), 1))
        return Color(
            .sRGB,
            red: Double(ar + (br - ar) * t),
            green: Double(ag + (bg - ag) * t),
            blue: Double(ab + (bb - ab) * t),
            opacity: Double(aa + (ba - aa) * t)
        )
        #else
        return amount >= 0.5 ? other : self
        #endif
    }
}
