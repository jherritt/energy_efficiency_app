import SwiftUI
import EnergyKit

/// "POINTS TODAY" summary card: the day's earned points against the maximum
/// available, with a thin gradient progress bar. The maximum drops to 80 when no
/// sleep data is present (bedtime/wake fall out), which `PointsBreakdown`
/// already reflects via `maxAvailable`. The total shown here is the SUM OF THE
/// ROUNDED per-line values, so it always matches the breakdown ledger exactly.
struct PointsCardView: View {
    let points: PointsBreakdown

    /// Sum of the six rows AS DISPLAYED (each rounded to an Int), so this card
    /// and `BreakdownView` visibly add up.
    private var earned: Int {
        [points.move, points.exercise, points.stand,
         points.bedtime, points.wake, points.hydration]
            .reduce(0) { $0 + Int($1.rounded()) }
    }
    private var maxAvailable: Int { Int(points.maxAvailable.rounded()) }
    private var fraction: Double {
        maxAvailable > 0 ? min(1, max(0, Double(earned) / Double(maxAvailable))) : 0
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
                    Text("\(earned)")
                        .font(.system(size: 40, weight: .heavy, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(Color.textHi)
                    Text("of \(maxAvailable)")
                        .font(.system(size: 17, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textLo)
                }

                progressBar
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Points today")
        .accessibilityValue("\(earned) of \(maxAvailable)")
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
