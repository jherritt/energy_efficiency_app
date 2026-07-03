import SwiftUI

/// The hero EFFICIENCY readout: a 0...100 number painted with the energy
/// gradient, an ALL-CAPS eyebrow, and a circular ring tracing the same value.
/// This is the app's signature element. A `nil` value renders as "--" with an
/// empty ring, never a fabricated zero.
struct EfficiencyHeroView: View {
    /// 0...100 efficiency, or nil when HealthKit is unauthorized.
    let efficiency: Double?

    @State private var appeared = false

    private var clamped: Double { min(100, max(0, efficiency ?? 0)) }
    private var hasValue: Bool { efficiency != nil }
    private var fraction: Double { clamped / 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("EFFICIENCY")
                .eyebrowStyle()

            HStack(spacing: DS.Space.md) {
                numberRow

                Spacer(minLength: 8)

                ring
                    .frame(width: 116, height: 116)
            }

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Color.textMid)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Efficiency")
        .accessibilityValue(hasValue ? "\(Int(clamped.rounded())) out of 100" : "No data")
    }

    private var numberRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
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
            .font(.system(size: 120, weight: .heavy, design: .default))
            .monospacedDigit()
            .tracking(-2)
            .shadow(color: Color.chargeMint.opacity(hasValue ? 0.45 : 0),
                    radius: 18, x: 0, y: 0)

            Text("/100")
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.textLo)
        }
        .minimumScaleFactor(0.45)
        .lineLimit(1)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.track, lineWidth: 13)

            Circle()
                .trim(from: 0, to: appeared && hasValue ? fraction : 0)
                .stroke(
                    AmperlyTheme.energyGradient,
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.chargeMint.opacity(0.5), radius: 9, x: 0, y: 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: fraction)

            if !hasValue {
                Image(systemName: "bolt.slash")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.textLo)
            }
        }
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

#Preview("No data") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        EfficiencyHeroView(efficiency: nil)
            .padding()
    }
}
