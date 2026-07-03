import SwiftUI

/// Amperly's signature element: a single centered ring gauge. The efficiency
/// number lives INSIDE the ring - eyebrow above, gradient-painted score in the
/// middle, "/100" beneath - with the energy gradient tracing the ring itself.
/// The ring sweeps from zero to the value once on appear. A `nil` value renders
/// as "--" over a dimmed track with no glow, never a fabricated zero.
struct EfficiencyHeroView: View {
    /// 0...100 efficiency, or nil when HealthKit is unauthorized.
    let efficiency: Double?

    /// False until first appearance so the ring can sweep in once on load.
    @State private var appeared = false

    private var clamped: Double { min(100, max(0, efficiency ?? 0)) }
    private var hasValue: Bool { efficiency != nil }
    private var fraction: Double { clamped / 100 }

    private let ringSize: CGFloat = 205
    private let ringWidth: CGFloat = 12

    var body: some View {
        VStack(spacing: DS.Space.md) {
            ZStack {
                // Track ring; dimmed when there is no data.
                Circle()
                    .stroke(Color.track.opacity(hasValue ? 1 : 0.45),
                            lineWidth: ringWidth)

                // Value stroke. The soft mint glow lives on the ring only.
                if hasValue {
                    Circle()
                        .trim(from: 0, to: appeared ? fraction : 0)
                        .stroke(
                            AmperlyTheme.energyGradient,
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Color.chargeMint.opacity(0.45), radius: 12)
                        .animation(.spring(response: 0.9, dampingFraction: 0.85),
                                   value: fraction)
                }

                readout
            }
            .frame(width: ringSize, height: ringSize)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Color.textMid)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.15)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Efficiency")
        .accessibilityValue(hasValue ? "\(Int(clamped.rounded())) out of 100" : "No data")
    }

    /// Eyebrow, score, and "/100" stacked inside the ring.
    private var readout: some View {
        VStack(spacing: 2) {
            Text("EFFICIENCY")
                .eyebrowStyle()

            Group {
                if hasValue {
                    Text("\(Int(clamped.rounded()))")
                        .foregroundStyle(AmperlyTheme.energyGradient)
                        .dsNumeric(clamped)
                } else {
                    Text("--")
                        .foregroundStyle(Color.textLo)
                }
            }
            .font(.system(size: 64, weight: .heavy, design: .default))
            .monospacedDigit()
            .tracking(-1)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text("/100")
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.textLo)
        }
        .padding(.horizontal, ringWidth + DS.Space.sm)
    }

    /// One-line interpretation of the score, shown beneath the ring.
    private var subtitle: String {
        guard hasValue else { return "Connect Apple Health to see your score." }
        switch clamped {
        case 85...: return "Excellent conversion"
        case 60...: return "On track"
        case 35...: return "Losing energy"
        default: return "Mostly idle drain"
        }
    }
}

#Preview("High") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        EfficiencyHeroView(efficiency: 88)
            .padding()
    }
}

#Preview("Mid") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        EfficiencyHeroView(efficiency: 54)
            .padding()
    }
}

#Preview("Low") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        EfficiencyHeroView(efficiency: 21)
            .padding()
    }
}

#Preview("No data") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        EfficiencyHeroView(efficiency: nil)
            .padding()
    }
}
