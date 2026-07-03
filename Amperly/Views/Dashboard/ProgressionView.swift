import SwiftUI
import EnergyKit

/// Compact progression strip: a level badge, an XP bar toward the next level,
/// and two streak chips (points streak, sleep streak). Renders nothing when
/// `progression` is nil so the dashboard degrades gracefully before any history
/// exists.
struct ProgressionView: View {
    let progression: Progression?

    var body: some View {
        if let progression {
            content(progression)
        }
    }

    @ViewBuilder
    private func content(_ p: Progression) -> some View {
        let fraction = p.xpForNextLevel > 0
            ? min(1, max(0, p.xpIntoLevel / p.xpForNextLevel))
            : 0

        CardContainer {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack(spacing: 12) {
                    levelBadge(p.level)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("LEVEL \(p.level)")
                                .eyebrowStyle()
                            Spacer()
                            Text("\(format(p.xpIntoLevel)) / \(format(p.xpForNextLevel)) XP")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Color.textMid)
                                .dsNumeric(p.xpIntoLevel)
                        }
                        xpBar(fraction: fraction)
                    }
                }

                HStack(spacing: DS.Space.sm) {
                    streakChip(symbol: "flame.fill",
                               value: p.pointsStreak,
                               best: p.longestPointsStreak,
                               caption: "points")
                    streakChip(symbol: "moon.stars.fill",
                               value: p.sleepStreak,
                               best: p.longestSleepStreak,
                               caption: "sleep")
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func levelBadge(_ level: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.inkBase)
                .overlay(
                    Circle().strokeBorder(AmperlyTheme.energyGradient, lineWidth: 2)
                )
            Text("\(level)")
                .font(.system(size: 20, weight: .heavy, design: .default))
                .monospacedDigit()
                .foregroundStyle(AmperlyTheme.energyGradient)
                .dsNumeric(level)
        }
        .frame(width: 48, height: 48)
    }

    private func xpBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.track)
                Capsule()
                    .fill(AmperlyTheme.energyGradient)
                    .frame(width: max(0, geo.size.width * fraction))
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: fraction)
            }
        }
        .frame(height: 6)
    }

    private func streakChip(symbol: String, value: Int, best: Int, caption: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(value > 0 ? Color.chargeMint : Color.textLo)
            Text("\(value)")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.textHi)
                .dsNumeric(value)
            Text(caption)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.textMid)
            if best > value && best > 0 {
                Text("best \(best)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textLo)
            }
        }
        .dsChip()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption) streak")
        .accessibilityValue("\(value) days, best \(best) days")
    }

    private func format(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}

#Preview("Active") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        ProgressionView(progression: Progression(
            level: 6, totalXP: 4200, xpIntoLevel: 320, xpForNextLevel: 800,
            pointsStreak: 12, sleepStreak: 5,
            longestPointsStreak: 28, longestSleepStreak: 14))
        .padding()
    }
}

#Preview("Fresh / nil") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        ProgressionView(progression: nil)
            .padding()
    }
}
