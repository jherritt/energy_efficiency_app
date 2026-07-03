import SwiftUI
import EnergyKit

/// The transparency screen: a plain-language, card-by-card explainer of every
/// number Amperly computes. Each card pairs the rule (in words a reviewer could
/// re-derive from `ScoringConstants`) with the user's live figure for today, so
/// nothing on the dashboard is a black box.
struct InsightsView: View {
    let score: DayScore

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Space.md) {
                headerCard
                morningChargeCard
                drainCard
                sleepDebtCard
                missingSleepCard
                pointsCard
                efficiencyCard
                privacyCard
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.lg)
        }
        .background(DS.AmbientBackground())
        .navigationTitle("How this works")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("Transparency").eyebrowStyle()
            Text("How Amperly works")
                .font(.system(.title2, design: .default, weight: .semibold))
                .foregroundStyle(Color.textHi)
            bodyText("Every number below is computed on your iPhone from Apple Health. Nothing is stored. Nothing leaves your device.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    // MARK: The morning charge

    private var morningChargeCard: some View {
        explainerCard(eyebrow: "The morning charge", symbol: "moon.zzz.fill") {
            bodyText("Your battery charges once, overnight. Five things set the size of the charge.")
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                factRow("Duration",
                        "sleep length against your target earns up to 85 points.")
                factRow("Quality",
                        "your deep and REM share and your sleep efficiency scale the charge by \u{00D7}0.85 to \u{00D7}1.08.")
                factRow("Recovery",
                        "overnight HRV, resting heart rate, wrist temperature, and breathing rate, each measured against your own baseline, scale it by \u{00D7}0.88 to \u{00D7}1.10.")
                factRow("Consistency",
                        "an on-time bed and wake adds up to 15 points, and a steady 7-day schedule adds up to 5 more.")
                factRow("Training load",
                        "when your 7-day load spikes over your 28-day norm, up to 5 points are trimmed.")
            }
            if let morning = score.morningBattery {
                liveRow("This morning", percent(morning))
            }
        }
    }

    // MARK: The drain

    private var drainCard: some View {
        explainerCard(eyebrow: "The drain", symbol: "bolt.fill") {
            bodyText("Being awake costs about 3% per hour, tuned to your metabolism. Each active calorie you burn adds about 0.06% on top. Time in daylight gives a small relief.")
            liveRow("Spent so far", percent(score.energySpent))
        }
    }

    // MARK: Sleep debt

    private var sleepDebtCard: some View {
        explainerCard(eyebrow: "Sleep debt", symbol: "clock.arrow.circlepath") {
            bodyText("Amperly keeps a rolling 14-night balance. Short nights add debt. Oversleep pays it down at half rate, with at most 2 hours of credit per night. The balance fades on its own over about a week and never grows past 20 hours. Each hour of debt costs 2% of the morning charge, up to 15%.")
            liveRow("Current debt",
                    score.sleepDebtHours > 0
                        ? "\(format(score.sleepDebtHours))h"
                        : "None")
        }
    }

    // MARK: When sleep is missing

    private var missingSleepCard: some View {
        explainerCard(eyebrow: "When sleep is missing", symbol: "questionmark.circle") {
            bodyText("If no sleep is recorded, Amperly never assumes zero or a perfect night. It estimates from your recent typical mornings, takes a small haircut for the uncertainty, and marks the day Estimated.")
            if score.batteryIsEstimated {
                noteRow("Today is an estimated day.")
            }
        }
    }

    // MARK: Points

    private var pointsCard: some View {
        explainerCard(eyebrow: "Points", symbol: "checklist") {
            bodyText("Points are a separate daily ledger. Every line pays partial credit, so progress counts even when you miss the goal. Bedtime and Wake pause when sleep is not recorded, and that day is scored out of 80 instead of 100.")
            VStack(spacing: DS.Space.xs) {
                pointRow("Move", score.points.move, ScoringConstants.movePointsMax)
                pointRow("Exercise", score.points.exercise, ScoringConstants.exercisePointsMax)
                pointRow("Stand", score.points.stand, ScoringConstants.standPointsMax)
                pointRow("Bedtime", score.points.bedtime, ScoringConstants.bedtimePointsMax,
                         paused: !score.points.sleepPointsAvailable)
                pointRow("Wake", score.points.wake, ScoringConstants.wakePointsMax,
                         paused: !score.points.sleepPointsAvailable)
                pointRow("Hydration", score.points.hydration, ScoringConstants.hydrationPointsMax)
            }
            liveRow("Total today", "\(format(score.points.total)) / \(format(score.points.maxAvailable))")
        }
    }

    // MARK: The efficiency score

    private var efficiencyCard: some View {
        explainerCard(eyebrow: "The efficiency score", symbol: "gauge.with.dots.needle.67percent") {
            bodyText("The score compares the points you have earned with the points your energy spend should have produced. A full day of spend is budgeted at 78%. Early in the morning the comparison is floored so a small spend cannot swing it. The score is fair at 9am and at 9pm.")
            if let efficiency = score.efficiency {
                liveRow("Right now", "\(Int(efficiency.rounded())) of 100")
            }
        }
    }

    // MARK: Privacy

    private var privacyCard: some View {
        explainerCard(eyebrow: "Privacy", symbol: "lock.fill") {
            bodyText("Amperly has read-only access to Apple Health. All scoring runs on this iPhone. There is no account and no analytics. Nothing is stored and nothing is transmitted.")
        }
    }

    // MARK: Building blocks

    /// One explainer card: icon badge + eyebrow, then the caller's content.
    private func explainerCard<Content: View>(eyebrow: String,
                                              symbol: String,
                                              @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.xs) {
                iconBadge(symbol)
                Text(eyebrow).eyebrowStyle()
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    /// Small tinted square holding the section's SF Symbol.
    private func iconBadge(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.chargeMint)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.chargeMint.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.chargeMint.opacity(0.16), lineWidth: 1)
            )
    }

    /// Footnote-size explanatory copy.
    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.textMid)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One rule of the model: a bolded term followed by its plain-language detail.
    private func factRow(_ term: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
            Circle()
                .fill(Color.chargeMint.opacity(0.55))
                .frame(width: 5, height: 5)
            (Text(term).fontWeight(.semibold).foregroundStyle(Color.textHi)
                + Text(" \u{2014} \(detail)").foregroundStyle(Color.textMid))
                .font(.footnote)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The user's live figure for this rule, separated by a hairline and marked
    /// with a small gradient dot.
    private func liveRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: DS.Space.sm) {
            Divider().overlay(Color.track)
            HStack(spacing: DS.Space.xs) {
                Circle()
                    .fill(AmperlyTheme.energyGradient)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(Color.textMid)
                Spacer()
                Text(value)
                    .font(.system(.callout, design: .default, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textHi)
            }
        }
    }

    /// A quiet status note (for example, the estimated-day marker).
    private func noteRow(_ text: String) -> some View {
        VStack(spacing: DS.Space.sm) {
            Divider().overlay(Color.track)
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.chargeCyan)
                Text(text)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.textHi)
                Spacer(minLength: 0)
            }
        }
    }

    /// One points line: earned versus maximum, or "Paused" when sleep is missing.
    private func pointRow(_ label: String, _ earned: Double, _ max: Double,
                          paused: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.textMid)
            Spacer()
            if paused {
                Text("Paused")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.textLo)
            } else {
                Text("\(format(earned)) / \(format(max))")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textHi)
            }
        }
    }

    // MARK: Formatting

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
            caffeineLateFlag: false,
            sleepDebtHours: 1.5))
    }
}

#Preview("Estimated day") {
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
