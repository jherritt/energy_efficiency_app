import SwiftUI

/// The hero EFFICIENCY readout: a 0...100 number painted with the energy
/// gradient, an ALL-CAPS eyebrow, and a circular ring tracing the same value.
/// This is the app's signature element. A `nil` value renders as "--" with an
/// empty ring, never a fabricated zero.
struct EfficiencyHeroView: View {
    /// 0...100 efficiency, or nil when HealthKit is unauthorized.
    let efficiency: Double?

    private var clamped: Double { min(100, max(0, efficiency ?? 0)) }
    private var hasValue: Bool { efficiency != nil }
    private var fraction: Double { clamped / 100 }

    var body: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("EFFICIENCY")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Color.textLo)

                numberRow

                Text(caption)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.textMid)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            ring
                .frame(width: 96, height: 96)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Efficiency")
        .accessibilityValue(hasValue ? "\(Int(clamped.rounded())) out of 100" : "No data")
    }

    private var numberRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Group {
                if hasValue {
                    Text("\(Int(clamped.rounded()))")
                        .foregroundStyle(AmperlyTheme.energyGradient)
                } else {
                    Text("--")
                        .foregroundStyle(Color.textLo)
                }
            }
            .font(.system(size: 64, weight: .heavy, design: .default))
            .monospacedDigit()
            .shadow(color: Color.chargeMint.opacity(hasValue ? 0.45 : 0),
                    radius: 14, x: 0, y: 0)

            Text("/100")
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.textLo)
        }
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.track, lineWidth: 12)

            Circle()
                .trim(from: 0, to: hasValue ? fraction : 0)
                .stroke(
                    AmperlyTheme.energyGradient,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.chargeMint.opacity(0.5), radius: 8, x: 0, y: 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: fraction)

            if !hasValue {
                Image(systemName: "bolt.slash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.textLo)
            }
        }
    }

    private var caption: String {
        guard hasValue else { return "Connect Apple Health to see your score." }
        switch clamped {
        case ..<40: return "Running ahead of budget."
        case ..<70: return "Steady spend so far today."
        default: return "Energy well in hand."
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
