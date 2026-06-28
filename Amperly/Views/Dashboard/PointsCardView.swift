import SwiftUI
import EnergyKit

/// "POINTS TODAY" summary card: the day's earned points against the maximum
/// available, with a thin gradient progress bar. The maximum drops to 80 when no
/// sleep data is present (bedtime/wake fall out), which `PointsBreakdown`
/// already reflects via `maxAvailable`.
struct PointsCardView: View {
    let points: PointsBreakdown

    private var earned: Double { points.total }
    private var maxAvailable: Double { points.maxAvailable }
    private var fraction: Double {
        maxAvailable > 0 ? min(1, max(0, earned / maxAvailable)) : 0
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("POINTS TODAY")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(Color.textLo)
                    Spacer()
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.chargeMint)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(format(earned))
                        .font(.system(size: 40, weight: .heavy, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(Color.textHi)
                    Text("of \(format(maxAvailable))")
                        .font(.system(size: 17, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textLo)
                }

                progressBar
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Points today")
        .accessibilityValue("\(format(earned)) of \(format(maxAvailable))")
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.track)
                Capsule()
                    .fill(AmperlyTheme.energyGradient)
                    .frame(width: max(0, geo.size.width * fraction))
                    .shadow(color: Color.chargeMint.opacity(0.4), radius: 6, x: 0, y: 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: fraction)
            }
        }
        .frame(height: 8)
    }

    private func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}

#Preview("With sleep") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        PointsCardView(points: PointsBreakdown(
            move: 22, exercise: 16, stand: 12,
            bedtime: 9, wake: 8, hydration: 14,
            sleepPointsAvailable: true))
        .padding()
    }
}

#Preview("No sleep") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        PointsCardView(points: PointsBreakdown(
            move: 18, exercise: 10, stand: 9,
            bedtime: 0, wake: 0, hydration: 12,
            sleepPointsAvailable: false))
        .padding()
    }
}
