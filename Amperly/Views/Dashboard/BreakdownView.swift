import SwiftUI
import EnergyKit

/// The six-line points ledger shown as rows: Move, Exercise, Stand, Bedtime,
/// Wake, Hydration. Each row pairs an SF Symbol and label with its earned/max
/// points and a mini progress indicator. When sleep was not detected, the
/// Bedtime and Wake rows are dimmed and annotated, since they cannot be earned.
struct BreakdownView: View {
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

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("BREAKDOWN")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Color.textLo)

                VStack(spacing: 14) {
                    ForEach(lines) { line in
                        row(for: line)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for line: Line) -> some View {
        let dimmed = line.isSleep && !points.sleepPointsAvailable
        let fraction = line.max > 0 ? min(1, max(0, line.earned / line.max)) : 0

        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: line.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22, alignment: .center)
                    .foregroundStyle(dimmed ? Color.textLo : Color.chargeMint)

                VStack(alignment: .leading, spacing: 1) {
                    Text(line.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(dimmed ? Color.textLo : Color.textHi)
                    if dimmed {
                        Text("No sleep data")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.textLo)
                    }
                }

                Spacer(minLength: 8)

                Text("\(format(line.earned)) / \(format(line.max))")
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(dimmed ? Color.textLo : Color.textMid)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.track)
                    if !dimmed {
                        Capsule()
                            .fill(AmperlyTheme.energyGradient)
                            .frame(width: max(0, geo.size.width * fraction))
                            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: fraction)
                    }
                }
            }
            .frame(height: 5)
        }
        .opacity(dimmed ? 0.7 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.label)
        .accessibilityValue(dimmed
            ? "No sleep data"
            : "\(format(line.earned)) of \(format(line.max)) points")
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
        BreakdownView(points: PointsBreakdown(
            move: 22, exercise: 16, stand: 12,
            bedtime: 9, wake: 8, hydration: 14,
            sleepPointsAvailable: true))
        .padding()
    }
}

#Preview("No sleep") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        BreakdownView(points: PointsBreakdown(
            move: 18, exercise: 10, stand: 9,
            bedtime: 0, wake: 0, hydration: 12,
            sleepPointsAvailable: false))
        .padding()
    }
}
