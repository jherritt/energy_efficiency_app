import SwiftUI
import EnergyKit

/// Amperly's main screen. A scrolling stack on the ambient background, top to
/// bottom: a compact TODAY header (the system navigation bar is hidden), the
/// centered efficiency ring hero, a row of stat chips (points / sleep debt /
/// level), the BATTERY card with the horizontal battery bar, the intraday
/// charts, the unified POINTS card, the progression strip, and a link into the
/// transparency screen. It pulls fresh data on appear and on pull-to-refresh,
/// both via `model.refresh()`.
struct DashboardView: View {
    @Environment(AmperlyModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Space.lg) {
                    header

                    EfficiencyHeroView(efficiency: model.score?.efficiency)
                        .frame(maxWidth: .infinity)

                    if model.score != nil || model.progression != nil {
                        statChips
                    }

                    batteryCard

                    EfficiencyChartView(series: model.hourlySeries)

                    if let points = model.score?.points {
                        PointsCardView(points: points)
                    }

                    ProgressionView(progression: model.progression)

                    if let score = model.score {
                        insightsLink(score: score)
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
            .task { await model.refresh() }
        }
    }

    // MARK: Header

    /// Compact custom header replacing the system navigation title: an eyebrow
    /// "TODAY" over the full weekday + date.
    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text("TODAY")
                .eyebrowStyle()
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.textHi)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.Space.sm)
        .accessibilityElement(children: .combine)
    }

    // MARK: Stat chips

    /// Points, sleep debt (>= 0.5h only), and level at a glance.
    private var statChips: some View {
        HStack(spacing: DS.Space.xs) {
            if let points = model.score?.points {
                pointsChip(points)
            }
            if let score = model.score, score.sleepDebtHours >= 0.5 {
                debtChip(hours: score.sleepDebtHours)
            }
            if let progression = model.progression {
                levelChip(progression.level)
            }
        }
    }

    private func pointsChip(_ points: PointsBreakdown) -> some View {
        // Sum of the six ledger rows AS DISPLAYED (each rounded), matching the
        // POINTS card total exactly.
        let total = [points.move, points.exercise, points.stand,
                     points.bedtime, points.wake, points.hydration]
            .reduce(0) { $0 + Int($1.rounded()) }
        return HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.chargeMint)
            Text("\(total) pts")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.textHi)
                .dsNumeric(total)
        }
        .dsChip()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Points today")
        .accessibilityValue("\(total)")
    }

    private func debtChip(hours: Double) -> some View {
        let heavy = hours >= 5
        let tint = heavy ? Color.drainWarn : Color.textMid
        return HStack(spacing: 5) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("\(String(format: "%.1f", hours))h debt")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .dsNumeric(hours)
        }
        .foregroundStyle(tint)
        .dsChip()
        .overlay {
            if heavy {
                Capsule(style: .continuous)
                    .strokeBorder(Color.drainWarn.opacity(0.5), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep debt")
        .accessibilityValue("\(String(format: "%.1f", hours)) hours")
    }

    private func levelChip(_ level: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.chargeMint)
            Text("Lv \(level)")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.textHi)
                .dsNumeric(level)
        }
        .dsChip()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level")
        .accessibilityValue("\(level)")
    }

    // MARK: Battery card

    /// The BATTERY card: eyebrow + bold percent header, the horizontal battery
    /// bar, and a footer with the morning charge and an "Estimated" chip when
    /// the charge had to be estimated (no sleep recorded).
    private var batteryCard: some View {
        let level = model.score?.currentBattery
        let morning = model.score?.morningBattery
        let estimated = model.score?.batteryIsEstimated ?? false

        return VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("BATTERY")
                    .eyebrowStyle()
                Spacer()
                if let level {
                    Text("\(Int(min(100, max(0, level)).rounded()))%")
                        .font(.system(size: 20, weight: .heavy, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(Color.textHi)
                        .dsNumeric(level)
                } else {
                    Text("--")
                        .font(.system(size: 20, weight: .heavy, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(Color.textLo)
                }
            }

            BatteryView(level: level)

            if morning != nil || estimated {
                HStack(spacing: DS.Space.xs) {
                    if let morning {
                        Text("Charged to \(Int(min(100, max(0, morning)).rounded()))% this morning")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textLo)
                    }
                    Spacer(minLength: 0)
                    if estimated {
                        estimatedChip
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .accessibilityElement(children: .contain)
    }

    private var estimatedChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 10, weight: .semibold))
            Text("Estimated")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Color.textLo)
        .dsChip()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Morning charge estimated from your recent sleep average")
    }

    // MARK: Insights link

    private func insightsLink(score: DayScore) -> some View {
        NavigationLink {
            InsightsView(score: score)
        } label: {
            CardContainer(padding: DS.Space.md) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.chargeMint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("How this works")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.textHi)
                        Text("See exactly how today's numbers were computed.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textMid)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textLo)
                }
            }
        }
        .buttonStyle(DSPressableStyle())
        .simultaneousGesture(TapGesture().onEnded { DS.tapHaptic(.light) })
    }
}

#Preview {
    DashboardView()
        .environment(AmperlyModel.preview)
}
