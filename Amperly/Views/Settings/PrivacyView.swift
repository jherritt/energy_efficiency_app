import SwiftUI

/// In-app, readable privacy statement. Mirrors the bundled privacy policy in plain
/// language. No emoji; SF Symbols only. Calm, high-contrast, Dynamic Type friendly.
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                header

                summaryCard

                ForEach(Self.sections) { section in
                    section.view
                }

                footer
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.AmbientBackground())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(PvColor.energyGradient, PvColor.track)
                .accessibilityHidden(true)

            Text("PRIVATE BY DESIGN")
                .eyebrowStyle()

            Text("Your data stays on your iPhone")
                .font(.system(.title2, design: .default, weight: .heavy))
                .foregroundStyle(PvColor.textHi)
                .fixedSize(horizontal: false, vertical: true)

            Text("Amperly is built to measure your energy without ever collecting it. This page explains exactly what that means.")
                .font(.body)
                .foregroundStyle(PvColor.textMid)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            ForEach(Self.promises, id: \.self) { promise in
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(PvColor.energyGradient)
                        .accessibilityHidden(true)
                    Text(promise)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PvColor.textHi)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PvColor.inkElev, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text("Last updated: 2025")
                .font(.footnote)
                .foregroundStyle(PvColor.textLo)
            Text("Measure the energy you actually use.")
                .font(.footnote)
                .foregroundStyle(PvColor.textLo)
        }
        .padding(.top, DS.Space.xxs)
    }

    // MARK: - Content

    private static let promises: [String] = [
        "No account and no sign-in",
        "Reads Apple Health on-device only",
        "Stores nothing, on the device or anywhere else",
        "Sends nothing off your iPhone",
        "No analytics, ads, or tracking"
    ]

    private struct Section: Identifiable {
        let id = UUID()
        let title: String
        let body: String

        @ViewBuilder var view: some View {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(title)
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .foregroundStyle(PvColor.textHi)
                Text(body)
                    .font(.body)
                    .foregroundStyle(PvColor.textMid)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static let sections: [Section] = [
        Section(
            title: "What Amperly reads",
            body: "With your permission, Amperly reads Apple Health data such as sleep, active and resting energy, steps, exercise and stand time, heart rate and heart rate variability, water intake, and time in daylight. Access is read-only. Amperly never writes to Apple Health."
        ),
        Section(
            title: "Where the work happens",
            body: "Every calculation, your battery, your points, and your efficiency score, runs on your iPhone. There is no server doing the math and no copy of your data leaving the device."
        ),
        Section(
            title: "What Amperly keeps",
            body: "Nothing personal. Amperly does not maintain a database of your health history. It reads what it needs from Apple Health when you open the app and computes your numbers live. The only things saved on the device are your own preferences, such as your sleep target and whether the low-energy nudge is on."
        ),
        Section(
            title: "No account, ever",
            body: "Amperly has no sign-in, no profile, and no cloud. You are never asked for an email, a phone number, or any identifier."
        ),
        Section(
            title: "No tracking",
            body: "Amperly contains no advertising and no third-party analytics or tracking software. Your behavior in the app is not measured, profiled, or sold."
        ),
        Section(
            title: "Notifications",
            body: "If you turn on the low-energy efficiency nudge, Amperly schedules a single local reminder on your device. It is created and delivered entirely on the iPhone and is never sent through a remote service."
        ),
        Section(
            title: "Your control",
            body: "You can revoke Amperly's access to Apple Health at any time in the Health app under Sharing. You can turn the notification off in Settings. Removing the app removes the few preferences it stored."
        )
    ]
}

// MARK: - Brand tokens (file-local to avoid cross-agent symbol collisions)

private enum PvColor {
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

#Preview("Privacy") {
    NavigationStack {
        PrivacyView()
    }
    .preferredColorScheme(.dark)
}
