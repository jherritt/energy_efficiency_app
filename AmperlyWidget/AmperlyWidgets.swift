//
//  AmperlyWidgets.swift
//  AmperlyWidget
//
//  Widget definitions and their views. Two widgets:
//    - AmperlyHomeWidget: .systemSmall and .systemMedium home-screen tiles.
//    - AmperlyLockWidget:  .accessoryCircular / .accessoryInline / .accessoryRectangular.
//
//  All numbers come from a live, on-device DayScore. Optional battery/efficiency
//  render as "--" (never a fabricated 0). No emoji; SF Symbols only.
//

import WidgetKit
import SwiftUI
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
        .supportedFamilies([.systemSmall, .systemMedium])
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
        case .systemMedium:
            HomeMediumView(score: entry.score)
        default:
            HomeSmallView(score: entry.score)
        }
    }
}

// MARK: Small home

private struct HomeSmallView: View {
    let score: DayScore

    var body: some View {
        HStack(spacing: 12) {
            WidgetBattery(level: score.currentBattery, width: 30, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                WidgetEyebrow(text: "Efficiency")
                Text(WidgetFormat.whole(score.efficiency))
                    .font(.system(size: 40, weight: .heavy, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(heroStyle)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("/ 100")
                    .font(.system(.caption2, design: .default).weight(.semibold))
                    .foregroundStyle(WidgetTheme.textLo)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(2)
    }

    private var heroStyle: AnyShapeStyle {
        score.efficiency == nil
            ? AnyShapeStyle(WidgetTheme.textLo)
            : AnyShapeStyle(WidgetTheme.energyGradient)
    }
}

// MARK: Medium home

private struct HomeMediumView: View {
    let score: DayScore

    var body: some View {
        HStack(spacing: 16) {
            // Left: battery + efficiency hero
            HStack(spacing: 12) {
                WidgetBattery(level: score.currentBattery, width: 32, height: 78)
                VStack(alignment: .leading, spacing: 2) {
                    WidgetEyebrow(text: "Efficiency")
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(WidgetFormat.whole(score.efficiency))
                            .font(.system(size: 44, weight: .heavy, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(heroStyle)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("/100")
                            .font(.system(.caption, design: .default).weight(.semibold))
                            .foregroundStyle(WidgetTheme.textLo)
                    }
                    Text(batteryLine)
                        .font(.system(.caption2, design: .default).weight(.medium))
                        .foregroundStyle(WidgetTheme.textMid)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: points total + a 3-line mini breakdown
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    WidgetEyebrow(text: "Points Today")
                }
                Text(pointsLine)
                    .font(.system(.title3, design: .default).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.textHi)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(alignment: .leading, spacing: 3) {
                    BreakdownRow(symbol: "flame.fill", label: "Move",
                                 value: score.isAuthorized ? score.points.move : nil)
                    BreakdownRow(symbol: "figure.run", label: "Exercise",
                                 value: score.isAuthorized ? score.points.exercise : nil)
                    BreakdownRow(symbol: "drop.fill", label: "Hydration",
                                 value: score.isAuthorized ? score.points.hydration : nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(2)
    }

    private var heroStyle: AnyShapeStyle {
        score.efficiency == nil
            ? AnyShapeStyle(WidgetTheme.textLo)
            : AnyShapeStyle(WidgetTheme.energyGradient)
    }

    private var batteryLine: String {
        guard let current = score.currentBattery else { return "Battery --" }
        return "Battery \(Int(current.rounded()))%"
    }

    private var pointsLine: String {
        guard score.isAuthorized else { return "-- / 100" }
        let total = Int(score.points.total.rounded())
        let maxAvail = Int(score.points.maxAvailable.rounded())
        return "\(total) / \(maxAvail)"
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
    AmperlyEntry(date: .now, score: AmperlyProvider.sampleScore(now: .now))
    AmperlyEntry(date: .now, score: .unauthorized(date: .now))
}

#Preview("Home Medium", as: .systemMedium) {
    AmperlyHomeWidget()
} timeline: {
    AmperlyEntry(date: .now, score: AmperlyProvider.sampleScore(now: .now))
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
