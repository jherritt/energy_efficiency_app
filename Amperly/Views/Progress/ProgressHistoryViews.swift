import SwiftUI
import Charts
import EnergyKit

// MARK: - Chart data point

/// One day's bar on a 30-day history chart. Built upstream so days without
/// data are skipped, never plotted as zero.
struct HistoryBar: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

// MARK: - History chart card

/// A 30-day bar chart card shared by the efficiency and points histories: one
/// bar per day, a dashed rule at the period average with a small "avg NN"
/// annotation, a fixed 0...100 domain, sparse weekday x labels, and hairline
/// gridlines.
struct HistoryChartCard: View {
    let title: String
    let bars: [HistoryBar]
    let barStyle: AnyShapeStyle

    private var average: Double? {
        guard !bars.isEmpty else { return nil }
        return bars.map(\.value).reduce(0, +) / Double(bars.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text(title)
                .eyebrowStyle()

            if bars.isEmpty {
                Text("No data in the last 30 days")
                    .font(.footnote)
                    .foregroundStyle(Color.textMid)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .multilineTextAlignment(.center)
            } else {
                chart
                    .frame(height: 170)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.capitalized)
        .accessibilityValue(average.map { "Average \(Int($0.rounded())) out of 100 across \(bars.count) days" }
            ?? "No data in the last 30 days")
    }

    private var chart: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Day", bar.date, unit: .day),
                    y: .value("Value", bar.value)
                )
                .foregroundStyle(barStyle)
                .cornerRadius(2)
            }

            if let average {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(Color.textLo)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        // Pill backing so the label stays legible over the bars.
                        Text("avg \(Int(average.rounded()))")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.textMid)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.inkBase.opacity(0.85)))
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.75))
                    .foregroundStyle(Color.track.opacity(0.8))
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
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color.textLo)
                    }
                }
            }
        }
    }
}

// MARK: - Recent days ledger

/// The last 14 days, newest first, one hairline-divided row per day: date,
/// efficiency (gradient-tinted), points, morning-to-now battery, and an "est"
/// chip when the morning charge was estimated. Days without data render dimmed
/// dashes instead of fabricated zeros.
struct RecentDaysCard: View {
    /// Newest first.
    let days: [DayScore]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("RECENT DAYS")
                .eyebrowStyle()

            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                    row(for: day)
                    if index < days.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 0.75)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    private func row(for day: DayScore) -> some View {
        let hasData = day.isAuthorized && day.efficiency != nil

        return HStack(spacing: DS.Space.sm) {
            Text(day.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textMid)
                .frame(width: 96, alignment: .leading)

            efficiencyText(day.efficiency, dimmed: !hasData)

            Spacer(minLength: DS.Space.xs)

            if hasData {
                Text("\(Int(day.points.total.rounded())) pts")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textHi)

                batteryText(morning: day.morningBattery, current: day.currentBattery)

                if day.batteryIsEstimated {
                    estChip
                }
            } else {
                Text("--")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textLo.opacity(0.7))
            }
        }
        .padding(.vertical, DS.Space.xs + 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(accessibilityValue(for: day, hasData: hasData))
    }

    @ViewBuilder
    private func efficiencyText(_ efficiency: Double?, dimmed: Bool) -> some View {
        if let efficiency, !dimmed {
            Text("\(Int(efficiency.rounded()))")
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AmperlyTheme.energyGradient)
        } else {
            Text("--")
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.textLo.opacity(0.7))
        }
    }

    @ViewBuilder
    private func batteryText(morning: Double?, current: Double?) -> some View {
        if let morning, let current {
            HStack(spacing: 3) {
                Text("\(Int(morning.rounded()))")
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .bold))
                Text("\(Int(current.rounded()))%")
            }
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Color.textLo)
        } else {
            Text("--")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textLo.opacity(0.7))
        }
    }

    private var estChip: some View {
        Text("est")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.textLo)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(Capsule(style: .continuous).strokeBorder(Color.track, lineWidth: 1))
    }

    private func accessibilityValue(for day: DayScore, hasData: Bool) -> String {
        guard hasData else { return "No data" }
        var parts: [String] = []
        if let efficiency = day.efficiency {
            parts.append("Efficiency \(Int(efficiency.rounded()))")
        }
        parts.append("\(Int(day.points.total.rounded())) points")
        if let morning = day.morningBattery, let current = day.currentBattery {
            parts.append("Battery \(Int(morning.rounded())) to \(Int(current.rounded())) percent")
        }
        if day.batteryIsEstimated {
            parts.append("estimated")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Previews

#Preview("History charts") {
    let model = AmperlyModel.preview
    return ZStack {
        DS.AmbientBackground()
        ScrollView {
            VStack(spacing: DS.Space.lg) {
                HistoryChartCard(
                    title: "EFFICIENCY - LAST 30 DAYS",
                    bars: model.history.compactMap { day in
                        day.efficiency.map { HistoryBar(date: day.date, value: $0) }
                    },
                    barStyle: AnyShapeStyle(AmperlyTheme.energyGradient.opacity(0.85)))

                HistoryChartCard(
                    title: "POINTS - LAST 30 DAYS",
                    bars: model.history.map { HistoryBar(date: $0.date, value: $0.points.total) },
                    barStyle: AnyShapeStyle(Color.chargeMint.opacity(0.7)))

                RecentDaysCard(days: model.history.suffix(14).reversed())
            }
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty chart") {
    ZStack {
        DS.AmbientBackground()
        HistoryChartCard(
            title: "EFFICIENCY - LAST 30 DAYS",
            bars: [],
            barStyle: AnyShapeStyle(AmperlyTheme.energyGradient.opacity(0.85)))
        .padding()
    }
    .preferredColorScheme(.dark)
}
