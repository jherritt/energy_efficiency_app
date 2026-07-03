import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Amperly's design system: the spacing grid, radii, surface treatments, and
/// micro-interaction helpers that every screen composes from. One source of
/// truth so the app reads as a single, deliberate piece of design.
enum DS {

    // MARK: Spacing (8pt grid)

    /// 4 / 8 / 12 / 16 / 20 / 24 / 32
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Radii (continuous curves everywhere)

    enum Radius {
        static let card: CGFloat = 22
        static let chip: CGFloat = 11
        static let control: CGFloat = 14
    }

    // MARK: Surfaces

    /// Subtle top-lit hairline used on every card edge: bright at the top,
    /// fading out toward the bottom. Reads as machined, not drawn.
    static let hairline = LinearGradient(
        colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
        startPoint: .top, endPoint: .bottom
    )

    /// Elevated card surface with a faint vertical tint so cards feel lit from
    /// above rather than flat.
    static let cardSurface = LinearGradient(
        colors: [Color.inkElev.opacity(1.0), Color.inkElev.opacity(0.72)],
        startPoint: .top, endPoint: .bottom
    )

    /// Ambient page background: near-black with a whisper of mint falloff at the
    /// top so the dark theme has depth instead of a void.
    struct AmbientBackground: View {
        var body: some View {
            ZStack {
                Color.inkBase
                RadialGradient(
                    colors: [Color.chargeMint.opacity(0.055), .clear],
                    center: .init(x: 0.5, y: -0.12),
                    startRadius: 0, endRadius: 420
                )
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Haptics

    /// Light, deliberate haptic for meaningful moments (refresh done, goal hit).
    static func tapHaptic(_ style: HapticStyle = .light) {
        #if canImport(UIKit)
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }

    enum HapticStyle { case light, success }
}

// MARK: - Card style

/// The one true card: continuous-corner surface, top-lit hairline border, and a
/// soft grounding shadow. Use via `.dsCard()`.
struct DSCardModifier: ViewModifier {
    var padding: CGFloat = DS.Space.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

// MARK: - Chip style

/// Small stat pill: hairline capsule on a slightly elevated fill.
struct DSChipModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DS.Space.sm)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(Color.inkBase.opacity(0.85)))
            .overlay(Capsule(style: .continuous).strokeBorder(DS.hairline, lineWidth: 1))
    }
}

// MARK: - Pressed-state scaling for tappable cards

struct DSPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - View conveniences

extension View {
    /// Standard Amperly card treatment.
    func dsCard(padding: CGFloat = DS.Space.lg) -> some View {
        modifier(DSCardModifier(padding: padding))
    }

    /// Standard stat-chip treatment.
    func dsChip() -> some View {
        modifier(DSChipModifier())
    }

    /// Animate numeric text changes with a rolling-digit transition. Attach to
    /// any Text whose number updates (efficiency, battery, points).
    func dsNumeric<V: Equatable>(_ value: V) -> some View {
        self
            .contentTransition(.numericText())
            .animation(.spring(response: 0.55, dampingFraction: 0.9), value: value)
    }
}
