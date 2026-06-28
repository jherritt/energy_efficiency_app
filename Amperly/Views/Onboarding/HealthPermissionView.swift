import SwiftUI

/// A focused, reusable permission-priming screen. Explains read-only Apple Health
/// access and that nothing leaves the device, then offers the Connect button.
///
/// Reusable from onboarding or from an empty/unauthorized state elsewhere in the
/// app. Premium, calm, electric. No emoji; all glyphs are SF Symbols.
struct HealthPermissionView: View {
    @Environment(AmperlyModel.self) private var model

    /// Called after the access request returns, so the host can advance or dismiss.
    var onConnected: () -> Void = {}

    @State private var isConnecting = false

    private let dataTypes: [(symbol: String, label: String)] = [
        ("bed.double.fill", "Sleep duration and stages"),
        ("flame.fill", "Active and resting energy"),
        ("figure.walk", "Steps, exercise, and stand"),
        ("heart.fill", "Heart rate and variability"),
        ("drop.fill", "Water intake"),
        ("sun.max.fill", "Time in daylight")
    ]

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 36)

                    hero

                    Spacer(minLength: 32)

                    VStack(spacing: 12) {
                        Text("CONNECT APPLE HEALTH")
                            .permissionEyebrow()

                        Text("Read-only, on your device")
                            .font(.system(.title, design: .default, weight: .heavy))
                            .foregroundStyle(HpColor.textHi)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Amperly reads your Health data live to compute your battery and efficiency. It computes everything on this iPhone and stores nothing. No account, no tracking.")
                            .font(.body)
                            .foregroundStyle(HpColor.textMid)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28)

                    Spacer(minLength: 28)

                    dataTypeList
                        .padding(.horizontal, 24)

                    Spacer(minLength: 24)
                }
            }

            VStack {
                Spacer()
                connectButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .background(
                        LinearGradient(
                            colors: [HpColor.inkBase.opacity(0), HpColor.inkBase],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    )
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [HpColor.chargeMint.opacity(0.28), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 150
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 12)

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 96, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(HpColor.energyGradient, HpColor.track)
                .shadow(color: HpColor.chargeMint.opacity(0.5), radius: 22)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Data type list

    private var dataTypeList: some View {
        VStack(spacing: 0) {
            ForEach(Array(dataTypes.enumerated()), id: \.element.label) { index, item in
                HStack(spacing: 14) {
                    Image(systemName: item.symbol)
                        .font(.body)
                        .foregroundStyle(HpColor.energyGradient)
                        .frame(width: 26)
                    Text(item.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(HpColor.textHi)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(HpColor.textLo)
                        .accessibilityLabel("Read only")
                }
                .padding(.vertical, 13)
                .padding(.horizontal, 16)

                if index < dataTypes.count - 1 {
                    Divider()
                        .overlay(HpColor.track)
                        .padding(.leading, 56)
                }
            }
        }
        .background(HpColor.inkElev, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Connect button

    private var connectButton: some View {
        Button {
            Task { await connect() }
        } label: {
            HStack(spacing: 10) {
                if isConnecting {
                    ProgressView()
                        .tint(HpColor.inkBase)
                } else {
                    Image(systemName: "heart.text.square.fill")
                }
                Text(isConnecting ? "Connecting" : "Connect Apple Health")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PermissionPrimaryButtonStyle())
        .disabled(isConnecting)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            HpColor.inkBase.ignoresSafeArea()
            RadialGradient(
                colors: [HpColor.chargeMint.opacity(0.14), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Action

    private func connect() async {
        isConnecting = true
        await model.requestHealthAccess()
        isConnecting = false
        onConnected()
    }
}

// MARK: - Button style

private struct PermissionPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(HpColor.inkBase)
            .padding(.vertical, 16)
            .background(
                HpColor.energyGradient,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: HpColor.chargeMint.opacity(0.35), radius: 16, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Eyebrow modifier

private extension View {
    func permissionEyebrow() -> some View {
        self
            .font(.system(.caption, design: .default, weight: .bold))
            .tracking(3)
            .foregroundStyle(HpColor.textLo)
            .textCase(.uppercase)
    }
}

// MARK: - Brand tokens (file-local to avoid cross-agent symbol collisions)

private enum HpColor {
    static let inkBase = Color(red: 0x06 / 255, green: 0x08 / 255, blue: 0x0B / 255)
    static let inkElev = Color(red: 0x0E / 255, green: 0x14 / 255, blue: 0x1A / 255)
    static let track = Color(red: 0x28 / 255, green: 0x30 / 255, blue: 0x39 / 255)
    static let chargeLime = Color(red: 0x9C / 255, green: 0xFF / 255, blue: 0x2E / 255)
    static let chargeMint = Color(red: 0x34 / 255, green: 0xF5 / 255, blue: 0xC5 / 255)
    static let chargeCyan = Color(red: 0x19 / 255, green: 0xC3 / 255, blue: 0xFF / 255)
    static let textHi = Color(red: 0xF4 / 255, green: 0xF7 / 255, blue: 0xFA / 255)
    static let textMid = Color(red: 0xA6 / 255, green: 0xB0 / 255, blue: 0xBB / 255)
    static let textLo = Color(red: 0x5C / 255, green: 0x67 / 255, blue: 0x72 / 255)

    static let energyGradient = LinearGradient(
        colors: [chargeLime, chargeMint, chargeCyan],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
}

// MARK: - Preview

#Preview("Health Permission") {
    HealthPermissionView()
        .environment(AmperlyModel.preview)
}
