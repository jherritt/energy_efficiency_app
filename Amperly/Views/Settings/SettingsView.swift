import SwiftUI
import UIKit
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
    @State private var notificationsDenied = false
    @State private var didLoad = false

    var body: some View {
        Form {
            targetsSection
            notificationsSection
            privacySection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(DS.AmbientBackground())
        .navigationTitle("Settings")
        .tint(Color.chargeMint)
        .onAppear(perform: loadFromModel)
    }

    // MARK: - Targets

    private var targetsSection: some View {
        Section {
            // Sleep target hours
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Stepper(value: $sleepTargetHours, in: 5...11, step: 0.5) {
                    HStack {
                        Label("Sleep target", systemImage: "bed.double.fill")
                            .labelStyle(SettingsRowLabelStyle())
                        Spacer()
                        Text(formattedHours(sleepTargetHours))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.textHi)
                    }
                }
                .tint(Color.chargeMint)
                .onChange(of: sleepTargetHours) { _, _ in commitTargets() }
            }

            // In-app bedtime fallback
            DatePicker(selection: $bedTime, displayedComponents: .hourAndMinute) {
                Label("Bedtime", systemImage: "moon.fill")
                    .labelStyle(SettingsRowLabelStyle())
            }
            .tint(Color.chargeMint)
            .onChange(of: bedTime) { _, _ in commitTargets() }

            // In-app wake time fallback
            DatePicker(selection: $wakeTime, displayedComponents: .hourAndMinute) {
                Label("Wake time", systemImage: "sunrise.fill")
                    .labelStyle(SettingsRowLabelStyle())
            }
            .tint(Color.chargeMint)
            .onChange(of: wakeTime) { _, _ in commitTargets() }

            // Water goal
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Stepper(value: $waterGoalLiters, in: 0.5...5.0, step: 0.25) {
                    HStack {
                        Label("Water goal", systemImage: "drop.fill")
                            .labelStyle(SettingsRowLabelStyle())
                        Spacer()
                        Text(formattedLiters(waterGoalLiters))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.textHi)
                    }
                }
                .tint(Color.chargeMint)
                .onChange(of: waterGoalLiters) { _, _ in commitTargets() }
            }
        } header: {
            sectionHeader("Targets")
        } footer: {
            Text("Bedtime and wake time are used when Apple Health does not provide a sleep schedule.")
                .foregroundStyle(Color.textLo)
        }
        .listRowBackground(Color.inkElev)
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: nudgeBinding) {
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Label("Low-energy efficiency nudge", systemImage: "bell.badge.fill")
                        .labelStyle(SettingsRowLabelStyle())
                    Text("One gentle afternoon reminder when the day is trending low.")
                        .font(.footnote)
                        .foregroundStyle(Color.textLo)
                }
            }
            .tint(Color.chargeMint)

            // Surface the system-level denial that otherwise makes the toggle
            // look broken: the app can never fire while iOS has it disabled.
            if notificationsDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.drainWarn)
                        Text("Notifications are turned off for Amperly in iOS Settings. Tap to open Settings and allow them.")
                            .font(.footnote)
                            .foregroundStyle(Color.textMid)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            sectionHeader("Notifications")
        }
        .listRowBackground(Color.inkElev)
        .task {
            notificationsDenied = await NotificationManager.shared.isDenied()
        }
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
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(AmperlyTheme.energyGradient)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    Text("Amperly stores no data. It reads Apple Health on your device only, with no account and no tracking.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textHi)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, DS.Space.xxs)

            NavigationLink {
                PrivacyView()
            } label: {
                Label("Privacy statement", systemImage: "doc.text.magnifyingglass")
                    .labelStyle(SettingsRowLabelStyle())
            }
        } header: {
            sectionHeader("Privacy")
        }
        .listRowBackground(Color.inkElev)
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "number")
                    .labelStyle(SettingsRowLabelStyle())
                Spacer()
                Text(Self.appVersion)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.textHi)
            }

            HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(AmperlyTheme.energyGradient)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text("Measure the energy you actually use.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textMid)
            }
            .padding(.vertical, DS.Space.xxs)
        } header: {
            sectionHeader("About")
        }
        .listRowBackground(Color.inkElev)
    }

    // MARK: - Section header style

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .eyebrowStyle()
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

// MARK: - Row label style

/// Row labels on the dark elevated rows: title in high-contrast brand text,
/// SF Symbol icon in the mint accent on a fixed-width column so every row's
/// title starts on the same left edge. Explicit colors keep every Form row
/// readable regardless of the system appearance.
private struct SettingsRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
                .foregroundStyle(Color.textHi)
        } icon: {
            configuration.icon
                .foregroundStyle(Color.chargeMint)
                .frame(width: 28)
        }
    }
}

// MARK: - Preview

#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .environment(AmperlyModel.preview)
    }
    .preferredColorScheme(.dark)
}
