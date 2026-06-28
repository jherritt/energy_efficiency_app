import SwiftUI

/// Three-page paged onboarding that introduces the battery concept, the single
/// efficiency score, and Amperly's privacy stance, ending in the Apple Health
/// connect step. Premium, calm, electric. No emoji anywhere; all glyphs are SF
/// Symbols.
struct OnboardingView: View {
    @Environment(AmperlyModel.self) private var model

    /// Called when onboarding completes (Health connected or skipped to app).
    var onFinished: () -> Void = {}

    @State private var page = 0
    @State private var isConnecting = false
    @State private var showWhyHealth = false

    private let pageCount = 3

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    conceptPage
                        .tag(0)
                    scorePage
                        .tag(1)
                    privacyPage
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: page)

                pageIndicator
                    .padding(.top, 8)

                controls
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
            }
            .padding(.top, 32)
        }
        .preferredColorScheme(nil)
        .sheet(isPresented: $showWhyHealth) {
            WhyHealthAccessSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Pages

    private var conceptPage: some View {
        OnboardingPage(
            symbol: "battery.100.bolt",
            eyebrow: "YOUR DAY",
            title: "Your day is a battery",
            body: "Sleep charges you overnight. Everything you do across the day draws that charge down. Amperly shows the whole arc, live, as a glowing battery you can read at a glance."
        ) {
            BatteryGlyph()
        }
    }

    private var scorePage: some View {
        OnboardingPage(
            symbol: "gauge.with.dots.needle.67percent",
            eyebrow: "ONE NUMBER",
            title: "One efficiency score that matters",
            body: "Efficiency is the energy you actually turned into results. Earn points across move, exercise, stand, sleep timing, and hydration, and watch a single score out of 100 tell you how well today is going."
        ) {
            ScoreGlyph()
        }
    }

    private var privacyPage: some View {
        OnboardingPage(
            symbol: "lock.shield",
            eyebrow: "PRIVATE BY DESIGN",
            title: "Private by design",
            body: "Amperly reads Apple Health live, computes everything on your device, and stores nothing. No account, no sign-in, no tracking. Your data never leaves your iPhone."
        ) {
            PrivacyGlyph()
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        if page < pageCount - 1 {
            Button {
                advance()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
        } else {
            VStack(spacing: 14) {
                Button {
                    Task { await connectHealth() }
                } label: {
                    HStack(spacing: 10) {
                        if isConnecting {
                            ProgressView()
                                .tint(OnbColor.inkBase)
                        } else {
                            Image(systemName: "heart.text.square.fill")
                        }
                        Text(isConnecting ? "Connecting" : "Connect Apple Health")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .disabled(isConnecting)

                Button {
                    showWhyHealth = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("Why Health access")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OnbColor.textMid)
                }
                .accessibilityHint("Lists the read-only Apple Health data types Amperly uses.")
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? AnyShapeStyle(OnbColor.energyGradient) : AnyShapeStyle(OnbColor.track))
                    .frame(width: index == page ? 26 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(pageCount)")
    }

    // MARK: - Actions

    private func advance() {
        withAnimation(.easeInOut(duration: 0.3)) {
            page = min(page + 1, pageCount - 1)
        }
    }

    private func connectHealth() async {
        isConnecting = true
        await model.requestHealthAccess()
        isConnecting = false
        onFinished()
    }
}

// MARK: - Page scaffold

/// A single onboarding page: hero illustration, eyebrow, title, body copy.
private struct OnboardingPage<Illustration: View>: View {
    let symbol: String
    let eyebrow: String
    let title: String
    let body: String
    @ViewBuilder var illustration: () -> Illustration

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            illustration()
                .frame(maxHeight: 220)

            Spacer(minLength: 28)

            VStack(spacing: 14) {
                Text(eyebrow)
                    .onboardingEyebrow()

                Text(title)
                    .font(.system(.largeTitle, design: .default, weight: .heavy))
                    .foregroundStyle(OnbColor.textHi)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(body)
                    .font(.body)
                    .foregroundStyle(OnbColor.textMid)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Illustrations (SF Symbols + gradient, no emoji)

private struct BatteryGlyph: View {
    var body: some View {
        ZStack {
            GlowHalo()
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 96, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(OnbColor.energyGradient, OnbColor.track)
                .shadow(color: OnbColor.chargeMint.opacity(0.5), radius: 24)
        }
        .accessibilityHidden(true)
    }
}

private struct ScoreGlyph: View {
    var body: some View {
        ZStack {
            GlowHalo()
            VStack(spacing: 2) {
                Text("87")
                    .font(.system(size: 88, weight: .heavy, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(OnbColor.energyGradient)
                    .shadow(color: OnbColor.chargeMint.opacity(0.5), radius: 22)
                Text("/100")
                    .font(.system(.title3, design: .default, weight: .bold))
                    .foregroundStyle(OnbColor.textLo)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PrivacyGlyph: View {
    var body: some View {
        ZStack {
            GlowHalo()
            Image(systemName: "lock.shield")
                .font(.system(size: 92, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(OnbColor.energyGradient, OnbColor.track)
                .shadow(color: OnbColor.chargeCyan.opacity(0.45), radius: 22)
        }
        .accessibilityHidden(true)
    }
}

/// Soft radial halo behind hero illustrations.
private struct GlowHalo: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [OnbColor.chargeMint.opacity(0.28), .clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: 160
                )
            )
            .frame(width: 300, height: 300)
            .blur(radius: 12)
    }
}

// MARK: - Background

private struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            OnbColor.inkBase
                .ignoresSafeArea()
            RadialGradient(
                colors: [OnbColor.chargeMint.opacity(0.16), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [OnbColor.chargeCyan.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 480
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Why Health access disclosure

/// Lists the read-only Apple Health data types in plain words.
private struct WhyHealthAccessSheet: View {
    private let items: [(symbol: String, title: String, detail: String)] = [
        ("bed.double.fill", "Sleep", "How long and how well you slept, to charge your morning battery."),
        ("flame.fill", "Active and resting energy", "The calories you burn, to drain the battery realistically across the day."),
        ("figure.walk", "Steps, exercise, and stand", "Your movement and activity rings, to award points."),
        ("heart.fill", "Heart rate and HRV", "Resting heart rate and variability, to fine-tune recovery."),
        ("drop.fill", "Water", "Hydration you log, to award points."),
        ("sun.max.fill", "Daylight", "Time in daylight, to ease the afternoon energy drain.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Amperly asks to read these Apple Health types. Access is read-only, everything is computed on your device, and nothing is stored or shared.")
                        .font(.subheadline)
                        .foregroundStyle(OnbColor.textMid)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(items, id: \.title) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.symbol)
                                .font(.title3)
                                .foregroundStyle(OnbColor.energyGradient)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(OnbColor.textHi)
                                Text(item.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(OnbColor.textMid)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(OnbColor.inkBase.ignoresSafeArea())
            .navigationTitle("Why Health access")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Button style

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(OnbColor.inkBase)
            .padding(.vertical, 16)
            .background(
                OnbColor.energyGradient,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: OnbColor.chargeMint.opacity(0.35), radius: 16, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Eyebrow modifier

private extension View {
    func onboardingEyebrow() -> some View {
        self
            .font(.system(.caption, design: .default, weight: .bold))
            .tracking(3)
            .foregroundStyle(OnbColor.textLo)
            .textCase(.uppercase)
    }
}

// MARK: - Brand tokens (file-local to avoid cross-agent symbol collisions)

private enum OnbColor {
    static let inkBase = Color(red: 0x06 / 255, green: 0x08 / 255, blue: 0x0B / 255)
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

#Preview("Onboarding") {
    OnboardingView()
        .environment(AmperlyModel.preview)
}
