//
//  WatchRootView.swift
//  Amperly Watch App
//

import SwiftUI
import EnergyKit

struct WatchRootView: View {
    @State private var model = WatchModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    WatchBattery(level: model.score?.currentBattery, width: 26, height: 58)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("EFFICIENCY")
                            .font(.system(.caption2).weight(.bold))
                            .tracking(2)
                            .foregroundStyle(WatchTheme.textLo)
                        Text(WatchFormat.whole(model.score?.efficiency))
                            .font(.system(size: 36, weight: .heavy))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .foregroundStyle(heroStyle)
                        Text("Battery \(WatchFormat.percent(model.score?.currentBattery))")
                            .font(.caption2)
                            .foregroundStyle(WatchTheme.textMid)
                    }
                    Spacer(minLength: 0)
                }

                if let points = model.score?.points {
                    HStack {
                        Text("POINTS")
                            .font(.system(.caption2).weight(.bold))
                            .tracking(2)
                            .foregroundStyle(WatchTheme.textLo)
                        Spacer()
                        Text("\(Int(points.total.rounded())) / \(Int(points.maxAvailable.rounded()))")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(WatchTheme.textHi)
                    }
                }

                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .tint(WatchTheme.chargeMint)
            }
            .padding(.horizontal, 6)
        }
        .task { await model.requestAccessAndRefresh() }
    }

    private var heroStyle: AnyShapeStyle {
        model.score?.efficiency == nil
            ? AnyShapeStyle(WatchTheme.textLo)
            : AnyShapeStyle(WatchTheme.energyGradient)
    }
}
