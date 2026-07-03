import SwiftUI

/// The horizontal battery bar. A full-width, continuous-corner shell with a
/// hairline `track` stroke and a small terminal cap nub on the right; the
/// interior fills left-to-right with `AmperlyTheme.batteryFill(forLevel:)`,
/// which already crossfades toward `drainWarn` when low. The fill sweeps in
/// from zero once on appear and carries a soft glow. The percent readout is NOT
/// drawn inside the bar - callers place it alongside (see the battery card).
/// A `nil` level renders as an empty track, never a fabricated zero.
struct BatteryView: View {
    /// 0...100 current battery, or nil when HealthKit is unauthorized.
    let level: Double?

    /// False until the first appearance so the fill can sweep from 0 once.
    @State private var appeared = false

    private var clamped: Double { min(100, max(0, level ?? 0)) }
    private var hasValue: Bool { level != nil }
    private var isLow: Bool { (level ?? 100) < AmperlyTheme.lowBatteryThreshold }
    /// The fraction actually drawn: 0 pre-appearance so the fill animates in.
    private var renderedFraction: Double { appeared && hasValue ? clamped / 100 : 0 }

    private let barHeight: CGFloat = 30
    private let shellRadius: CGFloat = 10
    private let fillInset: CGFloat = 3

    var body: some View {
        HStack(spacing: 3) {
            shell

            // Terminal cap nub on the right.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.track)
                .frame(width: 4, height: 12)
        }
        .onAppear { appeared = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Energy battery")
        .accessibilityValue(hasValue ? "\(Int(clamped.rounded())) percent" : "No data")
    }

    /// The shell with its left-to-right gradient fill.
    private var shell: some View {
        RoundedRectangle(cornerRadius: shellRadius, style: .continuous)
            .fill(Color.inkBase.opacity(0.7))
            .overlay {
                GeometryReader { geo in
                    let usableWidth = geo.size.width - fillInset * 2
                    if hasValue {
                        RoundedRectangle(cornerRadius: shellRadius - fillInset,
                                         style: .continuous)
                            .fill(AmperlyTheme.batteryFill(forLevel: clamped))
                            .frame(width: max(0, usableWidth * renderedFraction))
                            .shadow(color: (isLow ? Color.drainWarn : AmperlyTheme.glow).opacity(0.5),
                                    radius: 8)
                            .padding(fillInset)
                            .animation(.spring(response: 0.85, dampingFraction: 0.85),
                                       value: renderedFraction)
                            .animation(.easeInOut(duration: 0.4), value: isLow)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: shellRadius, style: .continuous)
                    .strokeBorder(Color.track, lineWidth: 1)
            )
            .frame(height: barHeight)
    }
}

#Preview("Charged") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        BatteryView(level: 76)
            .padding()
    }
}

#Preview("Low") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        BatteryView(level: 9)
            .padding()
    }
}

#Preview("No data") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        BatteryView(level: nil)
            .padding()
    }
}
