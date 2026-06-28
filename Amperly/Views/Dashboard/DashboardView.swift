import SwiftUI
import EnergyKit

/// Amperly's main screen. A scrolling stack on `inkBase` presents the hero
/// battery, the efficiency hero, the points card, the breakdown ledger, the
/// compact progression strip, and a link into the transparency screen. It pulls
/// fresh data on appear and on pull-to-refresh, both via `model.refresh()`.
struct DashboardView: View {
    @Environment(AmperlyModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BatteryView(level: model.score?.currentBattery)
                        .frame(height: 340)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    CardContainer {
                        EfficiencyHeroView(efficiency: model.score?.efficiency)
                    }

                    if let points = model.score?.points {
                        PointsCardView(points: points)
                        BreakdownView(points: points)
                    }

                    ProgressionView(progression: model.progression)

                    if let score = model.score {
                        insightsLink(score: score)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(Color.inkBase.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("Today")
            .refreshable { await model.refresh() }
            .task { await model.refresh() }
        }
    }

    private func insightsLink(score: DayScore) -> some View {
        NavigationLink {
            InsightsView(score: score)
        } label: {
            CardContainer(padding: 16) {
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
        .buttonStyle(.plain)
    }
}

#Preview {
    DashboardView()
        .environment(AmperlyModel.preview)
}
