//
//  AmperlyWidgets.swift
//  AmperlyWidget
//
//  Widget definitions and their views. Two widgets:
//    - AmperlyHomeWidget: .systemSmall / .systemMedium / .systemLarge tiles.
//      Efficiency leads on the LEFT; the battery is HORIZONTAL (terminal cap on
//      the right, fill grows left -> right). The large family adds a mini
//      intraday efficiency chart drawn with Swift Charts.
//    - AmperlyLockWidget:  .accessoryCircular / .accessoryInline / .accessoryRectangular.
//
//  All numbers come from a live, on-device DayScore. Optional battery/efficiency
//  render as "--" (never a fabricated 0). No emoji; SF Symbols only.
//

import WidgetKit
import SwiftUI
import Charts
import EnergyKit

// MARK: - Home widget

struct AmperlyHomeWidget: Widget {
    let kind = "AmperlyHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AmperlyProvider()) { entry in
            AmperlyHomeView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [WidgetTheme.inkElev, WidgetTheme.inkBase],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("Energy Battery")
        .description("Your daily energy battery and efficiency, live from Health.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Lock-screen widget

struct AmperlyLockWidget: Widget {
    let kind = "AmperlyLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AmperlyProvider()) { entry in
            AmperlyLockView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Energy")
        .description("Battery and efficiency on your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

// MARK: - Home view (routes by family)

struct AmperlyHomeView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AmperlyEntry

    var body: some View {
        switch family {
        case .systemLarge:
            HomeLargeView(score: entry.score, series: entry.series)
        case .systemMedium:
            HomeMediumView(score: entry.score)
        default:
            HomeSmallView(score: entry.score)
        }
    }
}

// MARK: Shared home helpers

/// The efficiency hero style: energy gradient when known, low-emphasis for "--".
private func heroStyle(for efficiency: Double?) -> AnyShapeStyle {
    efficiency == nil
        ? AnyShapeStyle(WidgetTheme.textLo)
        : AnyShapeStyle(WidgetTheme.energyGradient)
}

/// "NN / NN" of points earned vs. available, or "--" unauthorized.
private func pointsFraction(_ score: DayScore) -> String {
    guard score.isAuthorized else { return "-- / 100" }
    let total = Int(score.points.total.rounded())
    let maxAvail = Int(score.points.maxAvailable.rounded())
    return "\(total) / \(maxAvail)"
}

/// A horizontal WidgetBattery stretched to whatever width the layout offers.
private struct FlexibleBattery: View {
    let level: Double?
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            WidgetBattery(level: level, width: geo.size.width, height: height)
        }
        .frame(height: height)
    }
}

// MARK: Small home

/// Efficiency dominates on the left/top; the horizontal battery runs along the
/// bottom with a tiny caption.
private struct HomeSmallView: View {
    let score: DayScore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                WidgetEyebrow(text: "Efficiency")
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(WidgetFormat.whole(score.efficiency))
                        .font(.system(size: 46, weight: .heavy, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(heroStyle(for: score.efficiency))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("/100")
                        .font(.system(.caption2, design: .default).weight(.semibold))
                        .foregroundStyle(WidgetTheme.textLo)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("BATTERY \(WidgetFormat.percent(score.currentBattery))")
                    .font(.system(size: 9, weight: .bold, design: .default))
                    .tracking(1.5)
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.textMid)
                    .lineLimit(1)
                FlexibleBattery(level: score.currentBattery, height: 16)
            }
        }
        .padding(2)
    }
}

// MARK: Medium home

/// Efficiency block on the LEFT, horizontal battery on the RIGHT, exactly as
/// requested. Below the battery: a 3-line mini breakdown, or the sleep-debt
/// line when meaningful debt is carried into today.
private struct HomeMediumView: View {
    let score: DayScore

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // LEFT half: efficiency hero
            VStack(alignment: .leading, spacing: 2) {
                WidgetEyebrow(text: "Efficiency")
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(WidgetFormat.whole(score.efficiency))
                        .font(.system(size: 48, weight: .heavy, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(heroStyle(for: score.efficiency))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("/100")
                        .font(.system(.caption, design: .default).weight(.semibold))
                        .foregroundStyle(WidgetTheme.textLo)
                }
                Text("\(pointsFraction(score)) pts")
                    .font(.system(.caption2, design: .default).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.textMid)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // RIGHT half: horizontal battery with its percentage above
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    WidgetEyebrow(text: "Battery")
                    Spacer(minLength: 4)
                    Text(WidgetFormat.percent(score.currentBattery))
                        .font(.system(.callout, design: .default).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.textHi)
                }
                FlexibleBattery(level: score.currentBattery, height: 18)

                if score.sleepDebtHours >= 0.5 {
                    Text(String(format: "Debt %.1fh", score.sleepDebtHours))
                        .font(.system(.caption2, design: .default).weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.textMid)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        BreakdownRow(symbol: "flame.fill", label: "Move",
                                     value: score.isAuthorized ? score.points.move : nil)
                        BreakdownRow(symbol: "figure.run", label: "Exercise",
                                     value: score.isAuthorized ? score.points.exercise : nil)
                        BreakdownRow(symbol: "drop.fill", label: "Hydration",
                                     value: score.isAuthorized ? score.points.hydration : nil)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(2)
    }
}

// MARK: Large home

/// Efficiency hero on top, a mini intraday efficiency chart in the middle, and
/// a full-width horizontal battery with a three-stat row at the bottom.
private struct HomeLargeView: View {
    let score: DayScore
    let series: [EnergySeriesPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top: efficiency hero
            VStack(alignment: .leading, spacing: 2) {
                WidgetEyebrow(text: "Efficiency")
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(WidgetFormat.whole(score.efficiency))
                        .font(.system(size: 62, weight: .heavy, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(heroStyle(for: score.efficiency))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("/100")
                        .font(.system(.callout, design: .default).weight(.semibold))
                        .foregroundStyle(WidgetTheme.textLo)
                    Spacer(minLength: 8)
                    Text("\(pointsFraction(score)) pts")
                        .font(.system(.footnote, design: .default).weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.textMid)
                }
            }

            // Middle: mini intraday efficiency chart
            EfficiencyChart(series: series)
                .frame(height: 110)

            Spacer(minLength: 0)

            // Bottom: full-width horizontal battery + three stats
            VStack(alignment: .leading, spacing: 10) {
                FlexibleBattery(level: score.currentBattery, height: 22)
                HStack(alignment: .top) {
                    StatCell(label: "Battery",
                             value: WidgetFormat.percent(score.currentBattery))
                    Spacer(minLength: 8)
                    StatCell(label: "Points",
                             value: score.isAuthorized
                                ? "\(Int(score.points.total.rounded()))" : "--")
                    Spacer(minLength: 8)
                    StatCell(label: "Debt",
                             value: score.isAuthorized
                                ? String(format: "%.1fh", score.sleepDebtHours) : "--",
                             alignment: .trailing)
                }
            }
        }
        .padding(2)
    }
}

/// The large widget's mini chart: a gradient efficiency line over a soft area
/// fill. No y-axis; sparse hour marks along the bottom in the low text color.
private struct EfficiencyChart: View {
    let series: [EnergySeriesPoint]

    var body: some View {
        if series.isEmpty {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.track.opacity(0.35))
                .overlay(
                    Text("No intraday data yet")
                        .font(.system(.caption2, design: .default).weight(.medium))
                        .foregroundStyle(WidgetTheme.textLo)
                )
        } else {
            Chart(series) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Efficiency", point.efficiency)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [WidgetTheme.chargeMint.opacity(0.28),
                                 WidgetTheme.chargeCyan.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Efficiency", point.efficiency)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(WidgetTheme.energyGradient)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(WidgetTheme.textLo)
                }
            }
            .accessibilityLabel("Efficiency today")
        }
    }
}

/// One bottom-row stat in the large widget: eyebrow label + textMid value.
private struct StatCell: View {
    let label: String
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            WidgetEyebrow(text: label)
            Text(value)
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.textMid)
                .lineLimit(1)
        }
    }
}

/// One line of the medium-widget mini breakdown: SF Symbol + label + points.
private struct BreakdownRow: View {
    let symbol: String
    let label: String
    /// Points value, or nil for "--".
    let value: Double?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetTheme.chargeMint)
                .frame(width: 14)
            Text(label)
                .font(.system(.caption2, design: .default).weight(.medium))
                .foregroundStyle(WidgetTheme.textMid)
            Spacer(minLength: 4)
            Text(WidgetFormat.whole(value))
                .font(.system(.caption2, design: .default).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.textHi)
        }
    }
}

// MARK: - Lock-screen view (routes by family)

struct AmperlyLockView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AmperlyEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            LockInlineView(score: entry.score)
        case .accessoryRectangular:
            LockRectangularView(score: entry.score)
        default:
            LockCircularView(score: entry.score)
        }
    }
}

// MARK: Circular (efficiency gauge ring)

private struct LockCircularView: View {
    let score: DayScore

    var body: some View {
        Gauge(value: gaugeValue, in: 0...100) {
            Image(systemName: "bolt.fill")
        } currentValueLabel: {
            Text(WidgetFormat.whole(score.efficiency))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .accessibilityLabel("Efficiency")
        .accessibilityValue(efficiencyAccessibility)
    }

    private var efficiencyAccessibility: String {
        guard let eff = score.efficiency else { return "No data" }
        return "\(Int(eff.rounded())) of 100"
    }

    /// Gauge needs a concrete value; unauthorized shows an empty ring.
    private var gaugeValue: Double { score.efficiency ?? 0 }
}

// MARK: Inline (battery %)

private struct LockInlineView: View {
    let score: DayScore

    var body: some View {
        Label {
            Text("Battery \(WidgetFormat.percent(score.currentBattery))")
        } icon: {
            Image(systemName: batterySymbol)
        }
        .widgetAccentable()
        .accessibilityLabel("Battery")
        .accessibilityValue(WidgetFormat.percent(score.currentBattery))
    }

    /// Choose an SF Symbol battery glyph by level; lock screen is monochrome so
    /// we never rely on color to convey "low".
    private var batterySymbol: String {
        guard let level = score.currentBattery else { return "bolt.slash" }
        switch level {
        case ..<15: return "battery.25"
        case ..<50: return "battery.50"
        case ..<85: return "battery.75"
        default: return "battery.100"
        }
    }
}

// MARK: Rectangular (battery % + efficiency %)

private struct LockRectangularView: View {
    let score: DayScore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
                Text("AMPERLY")
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .tracking(2)
            }
            HStack(spacing: 6) {
                Image(systemName: "battery.100")
                    .font(.caption2)
                Text("Battery \(WidgetFormat.percent(score.currentBattery))")
                    .font(.system(.caption, design: .default).weight(.semibold))
                    .monospacedDigit()
            }
            HStack(spacing: 6) {
                Image(systemName: "gauge.medium")
                    .font(.caption2)
                Text("Efficiency \(WidgetFormat.percent(score.efficiency))")
                    .font(.system(.caption, design: .default).weight(.semibold))
                    .monospacedDigit()
            }
        }
        .widgetAccentable()
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Amperly energy")
        .accessibilityValue("Battery \(WidgetFormat.percent(score.currentBattery)), efficiency \(WidgetFormat.percent(score.efficiency))")
    }
}

// MARK: - Previews

#Preview("Home Small", as: .systemSmall) {
    AmperlyHomeWidget()
} timeline: {
    AmperlyEntry(date: .now, score: AmperlyProvider.sampleScore(now: .now),
                 series: AmperlyProvider.sampleSeries(now: .now))
    AmperlyEntry(date: .now, score: .unauthorized(date: .now))
}

#Preview("Home Medium", as: .systemMedium) {
    AmperlyHomeWidget()
} timeline: {
    AmperlyEntry(date: .now, score: AmperlyProvider.sampleScore(now: .now),
                 series: AmperlyProvider.sampleSeries(now: .now))
    AmperlyEntry(date: .now, score: .unauthorized(date: .now))
}

#Preview("Home Large", as: .systemLarge) {
    AmperlyHomeWidget()
} timeline: {
    AmperlyEntry(date: .now, score: AmperlyProvider.sampleScore(now: .now),
                 series: AmperlyProvider.sampleSeries(now: .now))
    AmperlyEntry(date: .now, score: .unauthorized(date: .now))
}

#Preview("Lock Circular", as: .accessoryCircular) {
    AmperlyLockWidget()
} timeline: {
    AmperlyEntry(date: .now, score: AmperlyProvider.sampleScore(now: .now))
    AmperlyEntry(date: .now, score: .unauthorized(date: .now))
}

#Preview("Lock Inline", as: .accessoryInline) {
    AmperlyLockWidget()
} timeline: {
    AmperlyEntry(date: .now, score: AmperlyProvider.sampleScore(now: .now))
}

#Preview("Lock Rectangular", as: .accessoryRectangular) {
    AmperlyLockWidget()
} timeline: {
    AmperlyEntry(date: .now, score: AmperlyProvider.sampleScore(now: .now))
    AmperlyEntry(date: .now, score: .unauthorized(date: .now))
}
