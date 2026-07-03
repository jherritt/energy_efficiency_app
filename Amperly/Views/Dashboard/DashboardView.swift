import SwiftUI
import EnergyKit

/// Amperly's main screen. A scrolling stack on the ambient background leads
/// with the EFFICIENCY hero floating unboxed above the cards (the app's
/// signature element), then the intraday
/// efficiency/battery charts, the battery (with sleep-debt and estimated-charge
/// context), the points card, the breakdown ledger, the compact progression
/// strip, and a link into the transparency screen. It pulls fresh data on
/// appear and on pull-to-refresh, both via `model.refresh()`.
struct DashboardView: View {
    @Environment(AmperlyModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Space.lg) {
                    EfficiencyHeroView(efficiency: model.score?.efficiency)
                        .padding(.horizontal, DS.Space.xxs)
                        .padding(.top, DS.Space.xs)

                    EfficiencyChartView(series: model.hourlySeries)

                    batterySection

                    if let points = model.score?.points {
                        PointsCardView(points: points)
                        BreakdownView(points: points)
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
            .navigationTitle("Today")
            .refreshable {
                await model.refresh()
                DS.tapHaptic(.success)
            }
            .task { await model.refresh() }
        }
    }

    // MARK: Battery + context

    /// The battery with its contextual footnotes: an "Estimated" note when the
    /// morning charge had to be estimated (no sleep recorded), and a compact
    /// sleep-debt pill once the carried debt is at least half an hour.
    private var batterySection: some View {
        VStack(spacing: DS.Space.sm) {
            BatteryView(level: model.score?.currentBattery)
                .frame(height: 240)
                .frame(maxWidth: .infinity)

            if let score = model.score {
                if score.batteryIsEstimated {
                    estimatedNote
                }
                if score.sleepDebtHours >= 0.5 {
                    sleepDebtPill(hours: score.sleepDebtHours)
                }
            }
        }
    }

    private var estimatedNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textLo)
            Text("Estimated from your recent sleep average")
                .font(.footnote)
                .foregroundStyle(Color.textMid)
        }
        .accessibilityElement(children: .combine)
    }

    private func sleepDebtPill(hours: Double) -> some View {
        let heavy = hours >= 5
        let tint = heavy ? Color.drainWarn : Color.textMid
        return HStack(spacing: 6) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("Sleep debt \(String(format: "%.1f", hours))h")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .dsChip()
        .overlay {
            if heavy {
                Capsule().strokeBorder(Color.drainWarn.opacity(0.5), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep debt")
        .accessibilityValue("\(String(format: "%.1f", hours)) hours")
    }

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
