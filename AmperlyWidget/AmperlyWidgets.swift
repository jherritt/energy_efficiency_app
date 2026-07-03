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
                    // The app's signature ambient surface (inkBase + faint mint
                    // radial falloff at the top), replicated in WidgetTheme.
                    WidgetTheme.ambientBackground
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
        VStack(alignment: .leading, spacing: WidgetTheme.spaceXS) {
            VStack(alignment: .leading, spacing: WidgetTheme.spaceXXS) {
                WidgetEyebrow(text: "Efficiency")
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(WidgetFormat.whole(score.efficiency))
                        .font(.system(size: 46, weight: .heavy, design: .default))
                        .tracking(-1)
                        .monospacedDigit()
                        .foregroundStyle(heroStyle(for: score.efficiency))
                        .shadow(color: WidgetTheme.chargeMint
                            .opacity(score.efficiency == nil ? 0 : 0.18),
                                radius: 8, x: 0, y: 0)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("/100")
                        .font(.system(.caption2, design: .default).weight(.semibold))
                        .foregroundStyle(WidgetTheme.textLo)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: WidgetTheme.spaceXXS) {
                HStack(alignment: .firstTextBaseline) {
                    WidgetEyebrow(text: "Battery")
                    Spacer(minLength: WidgetTheme.spaceXXS)
                    Text(WidgetFormat.percent(score.currentBattery))
                        .font(.system(.caption2, design: .default).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.textHi)
                }
                FlexibleBattery(level: score.currentBattery, height: 16)
            }
        }
    }
}

// MARK: Medium home

/// Efficiency block on the LEFT, horizontal battery on the RIGHT, exactly as
/// requested. Below the battery: a FIXED three-row detail slot so the layout
/// reads identically day to day. Move and Exercise always show; the third row
/// is Hydration normally, or the carried sleep debt when it is meaningful.
private struct HomeMediumView: View {
    let score: DayScore

    var body: some View {
        // firstTextBaseline puts both column eyebrows on one shared line.
        HStack(alignment: .firstTextBaseline, spacing: WidgetTheme.spaceMD) {
            // LEFT half: efficiency hero
            VStack(alignment: .leading, spacing: WidgetTheme.spaceXXS) {
                WidgetEyebrow(text: "Efficiency")
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(WidgetFormat.whole(score.efficiency))
                        .font(.system(size: 48, weight: .heavy, design: .default))
                        .tracking(-1)
                        .monospacedDigit()
                        .foregroundStyle(heroStyle(for: score.efficiency))
                        .shadow(color: WidgetTheme.chargeMint
                            .opacity(score.efficiency == nil ? 0 : 0.18),
                                radius: 8, x: 0, y: 0)
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

            // RIGHT half: horizontal battery with its percentage above, then
            // the fixed three-row slot.
            VStack(alignment: .leading, spacing: WidgetTheme.spaceXXS) {
                HStack(alignment: .firstTextBaseline) {
                    WidgetEyebrow(text: "Battery")
                    Spacer(minLength: WidgetTheme.spaceXXS)
                    Text(WidgetFormat.percent(score.currentBattery))
                        .font(.system(.callout, design: .default).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.textHi)
                }
                FlexibleBattery(level: score.currentBattery, height: 18)

                VStack(alignment: .leading, spacing: WidgetTheme.spaceXXS) {
                    BreakdownRow(symbol: "flame.fill", label: "Move",
                                 value: score.isAuthorized ? score.points.move : nil)
                    BreakdownRow(symbol: "figure.run", label: "Exercise",
                                 value: score.isAuthorized ? score.points.exercise : nil)
                    if score.sleepDebtHours >= 0.5 {
                        BreakdownRow(symbol: "moon.zzz.fill", label: "Debt",
                                     text: String(format: "%.1fh", score.sleepDebtHours))
                    } else {
                        BreakdownRow(symbol: "drop.fill", label: "Hydration",
                                     value: score.isAuthorized ? score.points.hydration : nil)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: Large home

/// Efficiency hero on top, a mini intraday efficiency chart in the middle,
/// then the battery (eyebrow + percent above the bar, matching medium) and a
/// two-stat row. Glance path: hero -> chart -> battery -> stats.
private struct HomeLargeView: View {
    let score: DayScore
    let series: [EnergySeriesPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.spaceSM) {
            // Top: efficiency hero
            VStack(alignment: .leading, spacing: WidgetTheme.spaceXXS) {
                WidgetEyebrow(text: "Efficiency")
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(WidgetFormat.whole(score.efficiency))
                        .font(.system(size: 62, weight: .heavy, design: .default))
                        .tracking(-1.5)
                        .monospacedDigit()
                        .foregroundStyle(heroStyle(for: score.efficiency))
                        .shadow(color: WidgetTheme.chargeMint
                            .opacity(score.efficiency == nil ? 0 : 0.18),
                                radius: 10, x: 0, y: 0)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("/100")
                        .font(.system(.callout, design: .default).weight(.semibold))
                        .foregroundStyle(WidgetTheme.textLo)
                    Spacer(minLength: WidgetTheme.spaceXS)
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

            // Bottom: battery header row above the bar (same grammar as the
            // medium family), then Points / Debt.
            VStack(alignment: .leading, spacing: WidgetTheme.spaceXS) {
                HStack(alignment: .firstTextBaseline) {
                    WidgetEyebrow(text: "Battery")
                    Spacer(minLength: WidgetTheme.spaceXXS)
                    Text(WidgetFormat.percent(score.currentBattery))
                        .font(.system(.callout, design: .default).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.textHi)
                }
                FlexibleBattery(level: score.currentBattery, height: 22)
                HStack(alignment: .top) {
                    StatCell(label: "Points",
                             value: score.isAuthorized
                                ? "\(Int(score.points.total.rounded()))" : "--")
                    Spacer(minLength: WidgetTheme.spaceXS)
                    StatCell(label: "Debt",
                             value: score.isAuthorized
                                ? String(format: "%.1fh", score.sleepDebtHours) : "--",
                             alignment: .trailing)
                }
            }
        }
    }
}

/// The large widget's mini chart: a gradient efficiency line over a soft area
/// fill, ending in a single emphasized "now" dot. The y-domain is fitted to
/// the data (with breathing room) so the day's shape is legible; no y-axis,
/// just sparse hour marks along the bottom in the low text color.
private struct EfficiencyChart: View {
    let series: [EnergySeriesPoint]

    /// Fit the domain to the data with 8pt of breathing room on each side,
    /// clamped to the metric's 0...100 range. Mirrors the axis-padding
    /// discipline used across the product.
    private var yDomain: ClosedRange<Double> {
        let values = series.map(\.efficiency)
        guard let lo = values.min(), let hi = values.max() else { return 0...100 }
        return max(0, lo - 8)...min(100, hi + 8)
    }

    var body: some View {
        if series.isEmpty {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WidgetTheme.track.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(WidgetTheme.hairline, lineWidth: 1)
                )
                .overlay(
                    Text("No intraday data yet")
                        .font(.system(.caption2, design: .default).weight(.medium))
                        .foregroundStyle(WidgetTheme.textLo)
                )
        } else {
            Chart {
                ForEach(series) { point in
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

                // Terminal "now" marker: a mint dot on an inkBase ring, the
                // only emphasized point on the line.
                if let last = series.last {
                    PointMark(
                        x: .value("Time", last.date),
                        y: .value("Efficiency", last.efficiency)
                    )
                    .symbolSize(81)
                    .foregroundStyle(WidgetTheme.inkBase)

                    PointMark(
                        x: .value("Time", last.date),
                        y: .value("Efficiency", last.efficiency)
                    )
                    .symbolSize(25)
                    .foregroundStyle(WidgetTheme.chargeMint)
                }
            }
            .chartYScale(domain: yDomain)
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

/// One bottom-row stat in the large widget: eyebrow label + textHi value.
private struct StatCell: View {
    let label: String
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: WidgetTheme.spaceXXS) {
            WidgetEyebrow(text: label)
            Text(value)
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.textHi)
                .lineLimit(1)
        }
    }
}

/// One line of the medium-widget detail slot: SF Symbol + label + value.
/// Icons stay in the low text color so the hero keeps sole ownership of the
/// brand accent.
private struct BreakdownRow: View {
    let symbol: String
    let label: String
    /// Preformatted value string ("18", "1.2h", or "--").
    let text: String

    init(symbol: String, label: String, text: String) {
        self.symbol = symbol
        self.label = label
        self.text = text
    }

    /// Convenience for point values; nil renders as "--".
    init(symbol: String, label: String, value: Double?) {
        self.init(symbol: symbol, label: label, text: WidgetFormat.whole(value))
    }

    var body: some View {
        HStack(spacing: WidgetTheme.spaceXS) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetTheme.textLo)
                .frame(width: 14)
            Text(label)
                .font(.system(.caption2, design: .default).weight(.medium))
                .foregroundStyle(WidgetTheme.textMid)
            Spacer(minLength: WidgetTheme.spaceXXS)
            Text(text)
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

// MARK: Lock battery glyph

/// Choose an SF Symbol battery glyph by level; lock screen is monochrome so we
/// never rely on color to convey "low". Shared by the inline and rectangular
/// families so the glyph always tracks the actual charge.
private func batterySymbol(forLevel level: Double?) -> String {
    guard let level else { return "bolt.slash" }
    switch level {
    case ..<15: return "battery.25"
    case ..<50: return "battery.50"
    case ..<85: return "battery.75"
    default: return "battery.100"
    }
}

// MARK: Inline (battery %)

private struct LockInlineView: View {
    let score: DayScore

    var body: some View {
        Label {
            Text("Battery \(WidgetFormat.percent(score.currentBattery))")
        } icon: {
            Image(systemName: batterySymbol(forLevel: score.currentBattery))
        }
        .widgetAccentable()
        .accessibilityLabel("Battery")
        .accessibilityValue(WidgetFormat.percent(score.currentBattery))
    }
}

// MARK: Rectangular (efficiency /100 + battery %)

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
            // Efficiency leads, in the product's "/100" unit grammar.
            HStack(spacing: 6) {
                Image(systemName: "gauge.medium")
                    .font(.caption2)
                Text("Efficiency \(WidgetFormat.whole(score.efficiency))/100")
                    .font(.system(.caption, design: .default).weight(.semibold))
                    .monospacedDigit()
            }
            HStack(spacing: 6) {
                Image(systemName: batterySymbol(forLevel: score.currentBattery))
                    .font(.caption2)
                Text("Battery \(WidgetFormat.percent(score.currentBattery))")
                    .font(.system(.caption, design: .default).weight(.semibold))
                    .monospacedDigit()
            }
        }
        .widgetAccentable()
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Amperly energy")
        .accessibilityValue("Efficiency \(WidgetFormat.whole(score.efficiency)) of 100, battery \(WidgetFormat.percent(score.currentBattery))")
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
