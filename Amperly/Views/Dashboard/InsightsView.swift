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
            VStack(alignment: .leading, spacing: 22) {
                intro
                chargeSection
                sleepDebtSection
                if score.batteryIsEstimated {
                    estimatedChargeSection
                }
                drainSection
                efficiencySection
                pointsSection
                privacyNote
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.inkBase.ignoresSafeArea())
        .navigationTitle("How this works")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Every number Amperly shows is computed on your device from Apple Health. Here is exactly how today added up.")
                .font(.system(size: 16))
                .foregroundStyle(Color.textMid)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Charge

    private var chargeSection: some View {
        section(title: "Charging from sleep", symbol: "moon.zzz.fill") {
            if let morning = score.morningBattery {
                paragraph("Last night's sleep charged your battery to \(percent(morning)) by the time you woke. A full eight hours of restful sleep would charge it near 100. Stage quality and overnight recovery can nudge this up or down by a few points, and any accumulated sleep debt is subtracted.")
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
            paragraph("Sleep debt is a running balance. Nights shorter than your target add to it, and sleeping past your target pays it down. The balance is capped at \(format(ScoringConstants.sleepDebtCapHours)) hours. Each hour of debt carried into today costs \(format(ScoringConstants.debtPenaltyPerHour)) battery-% off the morning charge, up to a maximum of \(format(ScoringConstants.debtPenaltyMax))%.")
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
            paragraph("No sleep was recorded last night, so this morning's charge was ESTIMATED from your average sleep over the last seven days. Because it is an estimate rather than a measured night, a confidence discount of \(format(ScoringConstants.sleepFallbackConfidence * 100))% is applied to that charge. Record a night of sleep and the estimate disappears.")
            if let morning = score.morningBattery {
                metricRow("Estimated battery at wake", percent(morning))
            }
        }
    }

    // MARK: Drain

    private var drainSection: some View {
        section(title: "Draining across the day", symbol: "bolt.fill") {
            paragraph("From the moment you wake, simply being awake spends about \(format(ScoringConstants.baselineDrainPerHour))% of battery per hour. Activity costs more: roughly \(format(ScoringConstants.activityDrainPerKcal * 100))% for every 100 active calories you burn. Daylight gives a small alertness rebate.")
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
                paragraph("Efficiency compares the energy you have spent against a standard daily budget of \(format(ScoringConstants.dailyEnergyBudget))%, the cost of one ordinary full day. Spending less than the budget by this point reads as high efficiency; spending more reads as low. It is a measure of pacing, not of doing less.")
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

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.chargeMint)
            Text("All of this is calculated on your iPhone. Amperly has no account and stores or sends nothing.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textMid)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
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
                        .font(.system(size: 18, weight: .bold))
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
