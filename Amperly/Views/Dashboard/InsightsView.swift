import SwiftUI
import EnergyKit

/// A plain-language transparency screen. It walks through, using the real
/// numbers from `score`, how the battery charged overnight, how it drained,
/// how each points line was earned, and how the efficiency hero number was
/// computed. There is no hidden math: every figure shown here can be reproduced
/// from `ScoringConstants` and the values displayed.
struct InsightsView: View {
    let score: DayScore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                intro
                chargeSection
                sleepDebtSection
                if score.batteryIsEstimated {
                    estimatedChargeSection
                }
                drainSection
                efficiencySection
                pointsSection
            }
            .padding(DS.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.AmbientBackground())
        .navigationTitle("How this works")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("How your energy score works")
                .font(.system(.title3, design: .default, weight: .semibold))
                .foregroundStyle(Color.textHi)
            paragraph("Your battery charges once, overnight, and drains through the day - the same idea as a car's fuel gauge. Everything is computed on your iPhone from Apple Health. Nothing is stored and nothing is sent anywhere.")
        }
    }

    // MARK: Charge

    private var chargeSection: some View {
        section(title: "Charging from sleep", symbol: "moon.zzz.fill") {
            if let morning = score.morningBattery {
                paragraph("The morning charge blends how long you slept with how well you slept. Duration is measured against your target (8 hours by default). Quality looks at your deep and REM sleep and how efficiently you slept. Recovery compares your overnight heart-rate variability, resting heart rate, and wrist temperature against your own recent baseline - the same body signals recovery trackers rely on most, because they reflect how rested your nervous system actually is. A consistent bed and wake schedule adds a small bonus, and a sustained spike in training load trims a few points.")
                metricRow("Battery at wake", percent(morning))
            } else if !score.isAuthorized {
                paragraph("Connect Apple Health to see how your sleep charged your battery.")
            } else if !score.hasSleepData {
                paragraph("No sleep was recorded for last night, so the battery starts from your activity instead. Wear your device to bed or log sleep to see the morning charge.")
            } else {
                paragraph("Sleep was detected but the morning battery is not available yet.")
            }
        }
    }

    // MARK: Sleep debt

    private var sleepDebtSection: some View {
        section(title: "Sleep debt", symbol: "clock.arrow.circlepath") {
            paragraph("Sleep adds up over time. Research on chronic short sleep shows missed sleep builds a debt night after night for about two weeks, and recovery is slow and only partial - one long lie-in pays back just part of what you owe. Amperly tracks a rolling 14-night sleep debt: short nights add to it, extra sleep chips away at it gradually, and it fades over roughly a week rather than all at once.")
            metricRow("Debt carried into today", "\(format(score.sleepDebtHours)) h")
            if score.sleepDebtHours > 0 {
                metricRow("Battery cost this morning",
                          "-\(format(min(ScoringConstants.debtPenaltyMax, score.sleepDebtHours * ScoringConstants.debtPenaltyPerHour)))%")
            } else {
                paragraph("You are carrying no debt right now, so nothing was subtracted.")
            }
        }
    }

    // MARK: Estimated charge (no sleep recorded)

    private var estimatedChargeSection: some View {
        section(title: "When sleep is missing", symbol: "questionmark.circle") {
            paragraph("If a night is not recorded, Amperly never assumes zero or a perfect night. It estimates from your recent typical mornings and clearly marks the day as an estimate.")
            if let morning = score.morningBattery {
                metricRow("Estimated battery at wake", percent(morning))
            }
        }
    }

    // MARK: Drain

    private var drainSection: some View {
        section(title: "Draining across the day", symbol: "bolt.fill") {
            paragraph("Through the day the battery drains from the energy you spend - a steady baseline for simply being awake, tuned to your own metabolism, plus the calories you burn moving, with a small lift when you get daylight.")
            metricRow("Energy spent so far", percent(score.energySpent))
            if let morning = score.morningBattery, let current = score.currentBattery {
                paragraph("That took your battery from \(percent(morning)) at wake down to \(percent(current)) now.")
                metricRow("Battery now", percent(current))
            } else if let current = score.currentBattery {
                metricRow("Battery now", percent(current))
            }
        }
    }

    // MARK: Efficiency

    private var efficiencySection: some View {
        section(title: "Your efficiency score", symbol: "gauge.with.dots.needle.67percent") {
            if let efficiency = score.efficiency {
                paragraph("Your efficiency score compares the points you have earned against the energy you have spent, so it stays fair at 9am and at 9pm.")
                metricRow("Daily energy budget", "\(format(ScoringConstants.dailyEnergyBudget))%")
                metricRow("Energy spent", percent(score.energySpent))
                metricRow("Efficiency", "\(Int(efficiency.rounded())) / 100")
            } else {
                paragraph("Connect Apple Health to compute your efficiency score.")
            }
        }
    }

    // MARK: Points

    private var pointsSection: some View {
        section(title: "How points were earned", symbol: "list.bullet.rectangle") {
            paragraph("Points are a separate daily ledger out of \(format(score.points.maxAvailable)). They reward hitting your goals and never change your efficiency score.")
            pointLine("Move", score.points.move, ScoringConstants.movePointsMax)
            pointLine("Exercise", score.points.exercise, ScoringConstants.exercisePointsMax)
            pointLine("Stand", score.points.stand, ScoringConstants.standPointsMax)
            if score.points.sleepPointsAvailable {
                pointLine("On-time bedtime", score.points.bedtime, ScoringConstants.bedtimePointsMax)
                pointLine("On-time wake", score.points.wake, ScoringConstants.wakePointsMax)
            } else {
                paragraph("Bedtime and wake points need sleep data, which was not recorded, so today's maximum is \(format(ScoringConstants.totalPointsNoSleep)) instead of \(format(ScoringConstants.totalPointsWithSleep)).")
            }
            pointLine("Hydration", score.points.hydration, ScoringConstants.hydrationPointsMax)

            Divider().overlay(Color.track)
            metricRow("Total today", "\(format(score.points.total)) / \(format(score.points.maxAvailable))")

            if score.caffeineLateFlag {
                paragraph("Note: caffeine was logged within \(format(ScoringConstants.caffeineCutoffHoursBeforeBed)) hours of your target bedtime, which can affect tonight's sleep.")
            }
        }
    }

    // MARK: Building blocks

    @ViewBuilder
    private func section<Content: View>(title: String,
                                        symbol: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.chargeMint)
                    Text(title)
                        .font(.system(.headline, design: .default, weight: .semibold))
                        .foregroundStyle(Color.textHi)
                }
                content()
            }
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(Color.textMid)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.textMid)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.textHi)
        }
    }

    private func pointLine(_ label: String, _ earned: Double, _ max: Double) -> some View {
        metricRow(label, "\(format(earned)) / \(format(max)) pts")
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}

#Preview("Full day") {
    NavigationStack {
        InsightsView(score: DayScore(
            date: Date(),
            isAuthorized: true,
            hasSleepData: true,
            morningBattery: 92,
            currentBattery: 64,
            energySpent: 28,
            efficiency: 88,
            points: PointsBreakdown(
                move: 22, exercise: 16, stand: 12,
                bedtime: 9, wake: 8, hydration: 14,
                sleepPointsAvailable: true),
            xp: 320,
            caffeineLateFlag: false))
    }
}

#Preview("No sleep") {
    NavigationStack {
        InsightsView(score: DayScore(
            date: Date(),
            isAuthorized: true,
            hasSleepData: false,
            morningBattery: 74,
            currentBattery: 52,
            energySpent: 22,
            efficiency: 74,
            points: PointsBreakdown(
                move: 18, exercise: 10, stand: 9,
                bedtime: 0, wake: 0, hydration: 12,
                sleepPointsAvailable: false),
            xp: 180,
            caffeineLateFlag: true,
            sleepDebtHours: 6.5,
            batteryIsEstimated: true))
    }
}
