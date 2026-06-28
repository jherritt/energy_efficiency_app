//
//  WatchComplications.swift
//  AmperlyWatchWidget
//
//  The Amperly watch complication, supporting the standard accessory families.
//  Renders "--" when HealthKit is not authorized. No emoji; SF Symbols only.
//

import WidgetKit
import SwiftUI
import EnergyKit

struct AmperlyComplication: Widget {
    let kind = "AmperlyComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            ComplicationView(score: entry.score)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Energy")
        .description("Your energy battery and efficiency, live from Health.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let score: DayScore

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Energy \(WatchFormat.percent(score.currentBattery)), Eff \(WatchFormat.whole(score.efficiency))")

        case .accessoryCorner:
            Image(systemName: "bolt.fill")
                .font(.title3)
                .widgetLabel {
                    Text("Eff \(WatchFormat.whole(score.efficiency)) of 100")
                }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill").font(.caption2)
                    Text("AMPERLY")
                        .font(.system(.caption2).weight(.bold))
                        .tracking(1)
                }
                Text("Battery \(WatchFormat.percent(score.currentBattery))")
                    .font(.caption2).monospacedDigit()
                Text("Efficiency \(WatchFormat.whole(score.efficiency)) / 100")
                    .font(.caption2).monospacedDigit()
            }
            .widgetAccentable()
            .frame(maxWidth: .infinity, alignment: .leading)

        default: // .accessoryCircular
            Gauge(value: score.efficiency ?? 0, in: 0...100) {
                Image(systemName: "bolt.fill")
            } currentValueLabel: {
                Text(WatchFormat.whole(score.efficiency)).monospacedDigit()
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        }
    }
}

#Preview("Circular", as: .accessoryCircular) {
    AmperlyComplication()
} timeline: {
    WatchEntry(date: .now, score: WatchProvider.sample())
}

#Preview("Rectangular", as: .accessoryRectangular) {
    AmperlyComplication()
} timeline: {
    WatchEntry(date: .now, score: WatchProvider.sample())
    WatchEntry(date: .now, score: .unauthorized(date: .now))
}
