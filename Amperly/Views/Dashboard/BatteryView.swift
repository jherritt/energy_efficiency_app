import SwiftUI

/// The large vertical phone-style battery that is Amperly's centerpiece.
///
/// A rounded-rectangle shell with a terminal cap sits on the `track` color. The
/// interior fills bottom-up to `level`% with `AmperlyTheme.batteryFill(forLevel:)`,
/// which already crossfades toward `drainWarn` below the low-battery threshold.
/// The fill carries a soft mint glow and a thin lightning highlight, and the
/// percentage sits in the center using SF Pro Display Heavy monospaced digits.
/// A `nil` level renders as "--" with an empty track, never a fabricated zero.
struct BatteryView: View {
    /// 0...100 current battery, or nil when HealthKit is unauthorized.
    let level: Double?

    /// False until the first appearance so the fill can sweep from 0 to the
    /// current level once on load.
    @State private var appeared = false

    private var clamped: Double { min(100, max(0, level ?? 0)) }
    /// The level actually drawn: 0 pre-appearance so the fill animates in.
    private var renderedLevel: Double { appeared ? clamped : 0 }
    private var isLow: Bool { (level ?? 100) < AmperlyTheme.lowBatteryThreshold }
    private var hasValue: Bool { level != nil }

    var body: some View {
        GeometryReader { geo in
            // Reserve a slim cap above the shell; the shell takes the rest.
            let capHeight = max(8, geo.size.height * 0.035)
            let capGap = capHeight * 0.4
            let shellHeight = geo.size.height - capHeight - capGap
            let shellWidth = min(geo.size.width, shellHeight * 0.52)
            let shellRadius = shellWidth * 0.28
            let inset = max(6, shellWidth * 0.09)
            let innerRadius = max(2, shellRadius - inset * 0.6)
            let capWidth = shellWidth * 0.34

            VStack(spacing: capGap) {
                // Terminal cap.
                RoundedRectangle(cornerRadius: capHeight * 0.45, style: .continuous)
                    .fill(Color.track)
                    .frame(width: capWidth, height: capHeight)

                ZStack {
                    // Shell + empty track interior.
                    RoundedRectangle(cornerRadius: shellRadius, style: .continuous)
                        .fill(Color.inkElev)
                        .overlay(
                            RoundedRectangle(cornerRadius: shellRadius, style: .continuous)
                                .strokeBorder(Color.track, lineWidth: max(3, inset * 0.5))
                        )

                    // Fill, anchored to the bottom, animating with the level.
                    GeometryReader { inner in
                        let usableHeight = inner.size.height - inset * 2
                        let fillHeight = max(0, usableHeight * CGFloat(renderedLevel / 100))

                        ZStack(alignment: .bottom) {
                            Color.clear
                            if hasValue {
                                fillShape(width: inner.size.width - inset * 2,
                                          height: fillHeight,
                                          radius: innerRadius)
                                    .padding(.bottom, inset)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }

                    // Center readout sits above the fill.
                    readout
                }
                .frame(width: shellWidth, height: shellHeight)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private func fillShape(width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(AmperlyTheme.batteryFill(forLevel: clamped))
            .overlay {
                // Thin lightning-bolt highlight rising up the fill.
                LightningBolt()
                    .stroke(
                        Color.textHi.opacity(0.85),
                        style: StrokeStyle(lineWidth: max(1.5, width * 0.02),
                                           lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: width * 0.34, height: min(height * 0.7, width * 0.95))
                    .opacity(height > width * 0.5 ? 0.9 : 0)
                    .blendMode(.overlay)
            }
            .shadow(color: (isLow ? Color.drainWarn : AmperlyTheme.glow).opacity(0.55),
                    radius: 18, x: 0, y: 0)
            .frame(width: width, height: height)
            .animation(.spring(response: 0.7, dampingFraction: 0.82), value: clamped)
            .animation(.easeInOut(duration: 0.4), value: isLow)
    }

    private var readout: some View {
        VStack(spacing: 2) {
            if hasValue {
                Text(percentText)
                    .font(.system(size: 44, weight: .heavy, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(Color.textHi)
                    .shadow(color: Color.inkBase.opacity(0.6), radius: 4, y: 1)
                    .dsNumeric(clamped)
            } else {
                Text("--")
                    .font(.system(size: 44, weight: .heavy, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(Color.textLo)
            }
        }
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Energy battery")
        .accessibilityValue(hasValue ? "\(Int(clamped.rounded())) percent" : "No data")
    }

    private var percentText: String {
        "\(Int(clamped.rounded()))%"
    }
}

/// A minimal lightning bolt used as a highlight inside the battery fill.
private struct LightningBolt: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.58, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h * 0.56))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.48, y: rect.minY + h * 0.56))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.40, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.86, y: rect.minY + h * 0.40))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.54, y: rect.minY + h * 0.40))
        p.closeSubpath()
        return p
    }
}

#Preview("Charged") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        BatteryView(level: 76)
            .frame(width: 200, height: 360)
    }
}

#Preview("Low") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        BatteryView(level: 9)
            .frame(width: 200, height: 360)
    }
}

#Preview("No data") {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        BatteryView(level: nil)
            .frame(width: 200, height: 360)
    }
}
