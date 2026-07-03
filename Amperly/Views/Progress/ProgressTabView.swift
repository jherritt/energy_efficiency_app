import SwiftUI
import EnergyKit

/// The Progress tab: the place to EXPLORE levels, streaks, and the last month
/// of history. A compact custom header leads into the level card (badge + XP
/// bar), a 2x2 streaks grid, two 30-day history charts (efficiency and points),
/// and a recent-days ledger. Everything renders from `model.history` and
/// `model.progression`; no queries of its own.
struct ProgressTabView: View {
    @Environment(AmperlyModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    header

                    if model.history.isEmpty && model.progression == nil {
                        emptyState
                    } else {
                        if let progression = model.progression {
                            LevelCard(progression: progression,
                                      daysTracked: model.history.count)
                            StreaksCard(progression: progression)
                        }

                        if model.history.isEmpty {
                            emptyState
                        } else {
                            HistoryChartCard(
                                title: "EFFICIENCY - LAST 30 DAYS",
                                bars: efficiencyBars,
                                barStyle: AnyShapeStyle(AmperlyTheme.energyGradient.opacity(0.85)))

                            HistoryChartCard(
                                title: "POINTS - LAST 30 DAYS",
                                bars: pointsBars,
                                barStyle: AnyShapeStyle(Color.chargeMint.opacity(0.7)))

                            RecentDaysCard(days: recentDays)
                        }
                    }
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, DS.Space.xxl)
            }
            .background(DS.AmbientBackground())
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await model.refresh()
                DS.tapHaptic(.success)
            }
        }
    }

    // MARK: Header

    /// Compact custom header in place of a navigation title: eyebrow + title.
    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text("PROGRESS")
                .eyebrowStyle()
            Text("Your history")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.textHi)
        }
        .padding(.top, DS.Space.md)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Chart data

    /// One bar per day with a real efficiency; nil-efficiency days are skipped
    /// so the chart never fabricates a zero.
    private var efficiencyBars: [HistoryBar] {
        model.history.compactMap { day in
            guard let efficiency = day.efficiency else { return nil }
            return HistoryBar(date: day.date, value: efficiency)
        }
    }

    /// One bar per authorized day of points; unauthorized days are skipped.
    private var pointsBars: [HistoryBar] {
        model.history.compactMap { day in
            guard day.isAuthorized else { return nil }
            return HistoryBar(date: day.date, value: day.points.total)
        }
    }

    /// The last 14 days, newest first, for the ledger.
    private var recentDays: [DayScore] {
        model.history.suffix(14).reversed()
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(AmperlyTheme.energyGradient)
                .shadow(color: AmperlyTheme.glow.opacity(0.4), radius: 14)
            Text("Your history builds as you use Amperly")
                .font(.system(size: 15))
                .foregroundStyle(Color.textMid)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }
}

// MARK: - Level card

/// The level identity card: a 64pt gradient-ringed badge, the XP bar toward the
/// next level (animates in on appear), and lifetime context (total XP, days
/// tracked).
private struct LevelCard: View {
    let progression: Progression
    let daysTracked: Int

    /// Drives the appear animation: the XP bar grows from zero into place.
    @State private var barRevealed = false

    private var xpFraction: Double {
        guard progression.xpForNextLevel > 0 else { return 0 }
        return min(1, max(0, progression.xpIntoLevel / progression.xpForNextLevel))
    }

    var body: some View {
        HStack(spacing: DS.Space.md) {
            levelBadge

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("LEVEL \(progression.level)")
                    .eyebrowStyle()

                xpBar

                HStack(spacing: DS.Space.xs) {
                    Text("\(wholeNumber(progression.xpIntoLevel)) / \(wholeNumber(progression.xpForNextLevel)) XP")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textMid)
                        .dsNumeric(progression.xpIntoLevel)

                    Spacer(minLength: 0)

                    Text("\(grouped(progression.totalXP)) total XP")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textLo)
                        .dsNumeric(progression.totalXP)
                }

                Text("\(daysTracked) days tracked")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.textLo)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.15)) {
                barRevealed = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(progression.level)")
        .accessibilityValue("\(wholeNumber(progression.xpIntoLevel)) of \(wholeNumber(progression.xpForNextLevel)) XP into this level, \(grouped(progression.totalXP)) total XP, \(daysTracked) days tracked")
    }

    private var levelBadge: some View {
        ZStack {
            Circle()
                .fill(Color.inkBase)
                .overlay(
                    Circle().strokeBorder(AmperlyTheme.energyGradient, lineWidth: 2.5)
                )
                .shadow(color: AmperlyTheme.glow.opacity(0.25), radius: 10)
            Text("\(progression.level)")
                .font(.system(size: 26, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(AmperlyTheme.energyGradient)
                .dsNumeric(progression.level)
        }
        .frame(width: 64, height: 64)
    }

    private var xpBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.track)
                Capsule()
                    .fill(AmperlyTheme.energyGradient)
                    .frame(width: max(0, geo.size.width * xpFraction * (barRevealed ? 1 : 0)))
            }
        }
        .frame(height: 6)
    }

    private func wholeNumber(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    private func grouped(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number.grouping(.automatic))
    }
}

// MARK: - Streaks card

/// A 2x2 grid of streak chips: current and best, for points and sleep. Current
/// streaks light their icon mint while they are alive.
private struct StreaksCard: View {
    let progression: Progression

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("STREAKS")
                .eyebrowStyle()

            Grid(horizontalSpacing: DS.Space.sm, verticalSpacing: DS.Space.sm) {
                GridRow {
                    streakChip(symbol: "flame.fill",
                               value: progression.pointsStreak,
                               caption: "Points streak",
                               isCurrent: true)
                    streakChip(symbol: "flame.fill",
                               value: progression.longestPointsStreak,
                               caption: "Best points",
                               isCurrent: false)
                }
                GridRow {
                    streakChip(symbol: "moon.stars.fill",
                               value: progression.sleepStreak,
                               caption: "Sleep streak",
                               isCurrent: true)
                    streakChip(symbol: "moon.stars.fill",
                               value: progression.longestSleepStreak,
                               caption: "Best sleep",
                               isCurrent: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    private func streakChip(symbol: String, value: Int, caption: String, isCurrent: Bool) -> some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isCurrent && value > 0 ? Color.chargeMint : Color.textLo)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 17, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color.textHi)
                    .dsNumeric(value)
                Text(caption)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textMid)
            }

            Spacer(minLength: 0)
        }
        .dsChip()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue("\(value) days")
    }
}

#Preview("Full history") {
    ProgressTabView()
        .environment(AmperlyModel.preview)
        .preferredColorScheme(.dark)
}

#Preview("Empty") {
    ProgressTabView()
        .environment(AmperlyModel())
        .preferredColorScheme(.dark)
}
