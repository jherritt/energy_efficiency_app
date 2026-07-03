import SwiftUI
import Charts
import EnergyKit

/// Tesla-style intraday chart card. The top chart traces today's EFFICIENCY as a
/// glowing gradient line over a soft mint area fill, with a dashed rule at the
/// day's average. A second, smaller chart below traces the BATTERY level using
/// the battery-fill gradient. Both charts share the same x domain (first to last
/// series point). With fewer than two points the card shows a quiet placeholder
/// instead of empty axes.
struct EfficiencyChartView: View {
    /// Today's intraday curve from `ScoringEngine.daySeries`.
    let series: [EnergySeriesPoint]

    private var hasEnoughData: Bool { series.count >= 2 }

    /// Shared x domain from the first to the last point of the day so both
    /// charts line up hour-for-hour.
    private var xDomain: ClosedRange<Date> {
        guard let first = series.first?.date,
              let last = series.last?.date,
              first < last else {
            let now = Date()
            return now...now.addingTimeInterval(3600)
        }
        return first...last
    }

    private var averageEfficiency: Double {
        guard !series.isEmpty else { return 0 }
        return series.map(\.efficiency).reduce(0, +) / Double(series.count)
    }

    /// Latest battery level, used to pick the battery-fill gradient so the
    /// small chart warms toward `drainWarn` when the day ends low.
    private var latestBattery: Double { series.last?.battery ?? 100 }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("TODAY'S EFFICIENCY")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Color.textLo)

                if hasEnoughData {
                    efficiencyChart
                        .frame(height: 170)

                    Text("BATTERY")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(Color.textLo)
                        .padding(.top, 6)

                    batteryChart
                        .frame(height: 84)
                } else {
                    Text("Charts appear as your day unfolds")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textLo)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's efficiency chart")
        .accessibilityValue(hasEnoughData
            ? "Average efficiency \(Int(averageEfficiency.rounded())) out of 100, battery now \(Int(latestBattery.rounded())) percent"
            : "Not enough data yet")
    }

    // MARK: Efficiency chart

    private var efficiencyChart: some View {
        Chart {
            ForEach(series) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Efficiency", point.efficiency)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.chargeMint.opacity(0.35), .clear],
                        startPoint: .top,
                        endPoint: .bottom)
                )

                // Wide, faint pass under the line reads as a glow on the dark card.
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Efficiency", point.efficiency),
                    series: .value("Layer", "glow")
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 7, lineCap: .round))
                .foregroundStyle(Color.chargeMint.opacity(0.22))

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Efficiency", point.efficiency),
                    series: .value("Layer", "line")
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(AmperlyTheme.energyGradient)
            }

            RuleMark(y: .value("Average", averageEfficiency))
                .foregroundStyle(Color.textLo)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing, spacing: 2) {
                    Text("avg \(Int(averageEfficiency.rounded()))")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textLo)
                }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...100)
        .chartYAxis { scoreYAxis }
        .chartXAxis { hourXAxis }
    }

    // MARK: Battery chart

    private var batteryChart: some View {
        Chart {
            ForEach(series) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Battery", point.battery)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(AmperlyTheme.batteryFill(forLevel: latestBattery).opacity(0.4))

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Battery", point.battery)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .foregroundStyle(AmperlyTheme.batteryFill(forLevel: latestBattery))
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...100)
        .chartYAxis { scoreYAxis }
        .chartXAxis { hourXAxis }
    }

    // MARK: Shared axes

    private var scoreYAxis: some AxisContent {
        AxisMarks(position: .leading, values: [0, 50, 100]) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.track)
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text("\(Int(number))")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textLo)
                }
            }
        }
    }

    private var hourXAxis: some AxisContent {
        AxisMarks(values: .stride(by: .hour, count: 3)) { value in
            AxisValueLabel {
                if let date = value.as(Date.self) {
                    Text(date, format: .dateTime.hour())
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.textLo)
                }
            }
        }
    }
}

#Preview("Full day") {
    let start = Calendar.current.startOfDay(for: .now).addingTimeInterval(7 * 3600)
    let batteries: [Double] = [92, 90, 87, 83, 80, 74, 70, 67, 63, 60, 58, 55, 51, 48, 45]
    let efficiencies: [Double] = [97, 95, 91, 86, 83, 76, 72, 70, 68, 66, 67, 65, 62, 60, 58]
    let sample: [EnergySeriesPoint] = batteries.indices.map { index in
        EnergySeriesPoint(
            date: start.addingTimeInterval(Double(index) * 3600),
            battery: batteries[index],
            efficiency: efficiencies[index],
            energySpent: Double(index) * 3.4,
            points: min(100, Double(index) * 6))
    }
    return ZStack {
        Color.inkBase.ignoresSafeArea()
        ScrollView {
            EfficiencyChartView(series: sample)
                .padding()
        }
    }
}

#Preview("Early morning / sparse") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        EfficiencyChartView(series: [
            EnergySeriesPoint(date: .now, battery: 91, efficiency: 98,
                              energySpent: 2, points: 4)
        ])
        .padding()
    }
}
