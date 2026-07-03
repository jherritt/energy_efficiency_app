import SwiftUI
import EnergyKit

/// The unified POINTS card: a header total (sum of the six ROUNDED rows over
/// the rounded maximum, so the ledger visibly adds up) above six compact rows -
/// Move, Exercise, Stand, Bedtime, Wake, Hydration. Each row pairs an SF Symbol
/// and label with a thin gradient progress bar and its earned/max points. Rows
/// that earned nothing dim; Bedtime/Wake read "no data" when sleep was not
/// detected, since those points cannot be earned (the maximum drops to 80,
/// which `PointsBreakdown.maxAvailable` already reflects).
struct PointsCardView: View {
    let points: PointsBreakdown

    private struct Line: Identifiable {
        let id = UUID()
        let label: String
        let symbol: String
        let earned: Double
        let max: Double
        let isSleep: Bool
    }

    private var lines: [Line] {
        [
            Line(label: "Move", symbol: "flame.fill",
                 earned: points.move, max: ScoringConstants.movePointsMax, isSleep: false),
            Line(label: "Exercise", symbol: "figure.run",
                 earned: points.exercise, max: ScoringConstants.exercisePointsMax, isSleep: false),
            Line(label: "Stand", symbol: "figure.stand",
                 earned: points.stand, max: ScoringConstants.standPointsMax, isSleep: false),
            Line(label: "Bedtime", symbol: "moon.fill",
                 earned: points.bedtime, max: ScoringConstants.bedtimePointsMax, isSleep: true),
            Line(label: "Wake", symbol: "sunrise.fill",
                 earned: points.wake, max: ScoringConstants.wakePointsMax, isSleep: true),
            Line(label: "Hydration", symbol: "drop.fill",
                 earned: points.hydration, max: ScoringConstants.hydrationPointsMax, isSleep: false),
        ]
    }

    /// Sum of the six rows AS DISPLAYED (each rounded to an Int), so the header
    /// total always matches the rows exactly.
    private var earned: Int {
        lines.reduce(0) { $0 + Int($1.earned.rounded()) }
    }
    private var maxAvailable: Int { Int(points.maxAvailable.rounded()) }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                header

                VStack(spacing: DS.Space.sm) {
                    ForEach(lines) { line in
                        row(for: line)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("POINTS")
                .eyebrowStyle()
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(earned)")
                    .font(.system(size: 20, weight: .heavy, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(Color.textHi)
                    .dsNumeric(earned)
                Text("/ \(maxAvailable)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textLo)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Points today")
        .accessibilityValue("\(earned) of \(maxAvailable)")
    }

    @ViewBuilder
    private func row(for line: Line) -> some View {
        let noData = line.isSleep && !points.sleepPointsAvailable
        let inactive = noData || line.earned == 0
        let fraction = line.max > 0 ? min(1, max(0, line.earned / line.max)) : 0

        HStack(spacing: DS.Space.sm) {
            Image(systemName: line.symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 20, alignment: .center)
                .foregroundStyle(inactive ? Color.textLo : Color.chargeMint)

            Text(line.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textMid)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            // Thin gradient progress bar filling the middle of the row.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.track)
                    if !noData {
                        Capsule()
                            .fill(AmperlyTheme.energyGradient)
                            .frame(width: max(0, geo.size.width * fraction))
                            .animation(.spring(response: 0.6, dampingFraction: 0.85),
                                       value: fraction)
                    }
                }
            }
            .frame(height: 4)

            Group {
                if noData {
                    Text("no data")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textLo)
                } else {
                    Text("\(Int(line.earned.rounded()))/\(Int(line.max.rounded()))")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textHi)
                }
            }
            .frame(minWidth: 44, alignment: .trailing)
            .lineLimit(1)
        }
        .opacity(inactive ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.label)
        .accessibilityValue(noData
            ? "No sleep data"
            : "\(Int(line.earned.rounded())) of \(Int(line.max.rounded())) points")
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
            move: 18, exercise: 0, stand: 9,
            bedtime: 0, wake: 0, hydration: 12,
            sleepPointsAvailable: false))
        .padding()
    }
}
