import SwiftUI
import EnergyKit

/// Settings for Amperly. Targets, the single notification opt-in, privacy, and
/// about. Editing a target calls back into the model to persist and refresh.
///
/// Model contract (owned by `AmperlyModel`, assumed injected):
///   - `var targets: UserTargets { get }`
///   - `func updateTargets(_:) async` - persists and refreshes the day's score
///   - `var lowEfficiencyNudgeEnabled: Bool { get }`
///   - `func setLowEfficiencyNudgeEnabled(_:) async` - persists the opt-in and,
///     when enabling, requests notification authorization via NotificationManager
///
/// No emoji anywhere; SF Symbols only.
struct SettingsView: View {
    @Environment(AmperlyModel.self) private var model

    /// Local editing mirror of the targets so steppers/pickers feel instant; each
    /// commit pushes back into the model to persist and refresh.
    @State private var sleepTargetHours: Double = ScoringConstants.sleepTargetHours
    @State private var bedTime: Date = SettingsView.defaultBedTime
    @State private var wakeTime: Date = SettingsView.defaultWakeTime
    @State private var waterGoalLiters: Double = ScoringConstants.defaultWaterGoalML / 1000.0

    @State private var nudgeEnabled: Bool = false
    @State private var didLoad = false

    var body: some View {
        Form {
            targetsSection
            notificationsSection
            privacySection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(SetColor.inkBase.ignoresSafeArea())
        .navigationTitle("Settings")
        .tint(SetColor.chargeMint)
        .onAppear(perform: loadFromModel)
    }

    // MARK: - Targets

    private var targetsSection: some View {
        Section {
            // Sleep target hours
            VStack(alignment: .leading, spacing: 6) {
                Stepper(value: $sleepTargetHours, in: 5...11, step: 0.5) {
                    HStack {
                        Label("Sleep target", systemImage: "bed.double.fill")
                            .labelStyle(.titleAndIcon)
                        Spacer()
                        Text(formattedHours(sleepTargetHours))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(SetColor.textHi)
                    }
                }
                .onChange(of: sleepTargetHours) { _, _ in commitTargets() }
            }

            // In-app bedtime fallback
            DatePicker(selection: $bedTime, displayedComponents: .hourAndMinute) {
                Label("Bedtime", systemImage: "moon.fill")
            }
            .onChange(of: bedTime) { _, _ in commitTargets() }

            // In-app wake time fallback
            DatePicker(selection: $wakeTime, displayedComponents: .hourAndMinute) {
                Label("Wake time", systemImage: "sunrise.fill")
            }
            .onChange(of: wakeTime) { _, _ in commitTargets() }

            // Water goal
            VStack(alignment: .leading, spacing: 6) {
                Stepper(value: $waterGoalLiters, in: 0.5...5.0, step: 0.25) {
                    HStack {
                        Label("Water goal", systemImage: "drop.fill")
                        Spacer()
                        Text(formattedLiters(waterGoalLiters))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(SetColor.textHi)
                    }
                }
                .onChange(of: waterGoalLiters) { _, _ in commitTargets() }
            }
        } header: {
            sectionHeader("Targets")
        } footer: {
            Text("Bedtime and wake time are used when Apple Health does not provide a sleep schedule.")
                .foregroundStyle(SetColor.textLo)
        }
        .listRowBackground(SetColor.inkElev)
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: nudgeBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Low-energy efficiency nudge", systemImage: "bell.badge.fill")
                    Text("One gentle afternoon reminder when the day is trending low.")
                        .font(.footnote)
                        .foregroundStyle(SetColor.textLo)
                }
            }
        } header: {
            sectionHeader("Notifications")
        }
        .listRowBackground(SetColor.inkElev)
    }

    /// Toggling persists the opt-in via the model, which requests authorization
    /// when turning on. We mirror the value locally for instant feedback.
    private var nudgeBinding: Binding<Bool> {
        Binding(
            get: { nudgeEnabled },
            set: { newValue in
                nudgeEnabled = newValue
                Task { await model.setLowEfficiencyNudgeEnabled(newValue) }
            }
        )
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(SetColor.energyGradient)
                        .accessibilityHidden(true)
                    Text("Amperly stores no data. It reads Apple Health on your device only, with no account and no tracking.")
                        .font(.subheadline)
                        .foregroundStyle(SetColor.textHi)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)

            NavigationLink {
                PrivacyView()
            } label: {
                Label("Privacy statement", systemImage: "doc.text.magnifyingglass")
            }
        } header: {
            sectionHeader("Privacy")
        }
        .listRowBackground(SetColor.inkElev)
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "number")
                Spacer()
                Text(Self.appVersion)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(SetColor.textMid)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(SetColor.energyGradient)
                    .accessibilityHidden(true)
                Text("Measure the energy you actually use.")
                    .font(.subheadline.italic())
                    .foregroundStyle(SetColor.textMid)
            }
            .padding(.vertical, 2)
        } header: {
            sectionHeader("About")
        }
        .listRowBackground(SetColor.inkElev)
    }

    // MARK: - Section header style

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .default, weight: .bold))
            .tracking(3)
            .foregroundStyle(SetColor.textLo)
            .textCase(.uppercase)
    }

    // MARK: - Load / commit

    private func loadFromModel() {
        guard !didLoad else { return }
        didLoad = true

        let targets = model.targets
        sleepTargetHours = targets.sleepTargetHours
        waterGoalLiters = targets.waterGoalML / 1000.0
        bedTime = Self.date(from: targets.bedTarget) ?? Self.defaultBedTime
        wakeTime = Self.date(from: targets.wakeTarget) ?? Self.defaultWakeTime
        nudgeEnabled = model.lowEfficiencyNudgeEnabled
    }

    /// Builds a fresh `UserTargets` from the local edits and asks the model to
    /// persist and refresh. Existing non-edited fields are preserved.
    private func commitTargets() {
        let current = model.targets
        let updated = UserTargets(
            sleepTargetHours: sleepTargetHours,
            bedTarget: Self.components(from: bedTime),
            wakeTarget: Self.components(from: wakeTime),
            onTimeWindowMinutes: current.onTimeWindowMinutes,
            moveGoalKcal: current.moveGoalKcal,
            exerciseGoalMinutes: current.exerciseGoalMinutes,
            standGoalHours: current.standGoalHours,
            waterGoalML: waterGoalLiters * 1000.0
        )
        Task { await model.updateTargets(updated) }
    }

    // MARK: - Formatting

    private func formattedHours(_ hours: Double) -> String {
        let whole = Int(hours)
        let half = hours - Double(whole) >= 0.5
        if half {
            return "\(whole)h 30m"
        }
        return "\(whole)h"
    }

    private func formattedLiters(_ liters: Double) -> String {
        String(format: "%.2g L", liters)
    }

    // MARK: - Date <-> components

    private static func components(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }

    private static func date(from components: DateComponents) -> Date? {
        Calendar.current.date(from: DateComponents(
            hour: components.hour ?? 23,
            minute: components.minute ?? 0
        )) ?? Calendar.current.date(bySettingHour: components.hour ?? 23,
                                    minute: components.minute ?? 0,
                                    second: 0,
                                    of: Date())
    }

    private static var defaultBedTime: Date {
        date(from: DateComponents(hour: 23, minute: 0)) ?? Date()
    }

    private static var defaultWakeTime: Date {
        date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    }

    private static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let build, !build.isEmpty {
            return "\(version) (\(build))"
        }
        return version
    }
}

// MARK: - Brand tokens (file-local to avoid cross-agent symbol collisions)

private enum SetColor {
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

#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .environment(AmperlyModel.preview)
    }
    .preferredColorScheme(.dark)
}
