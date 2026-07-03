import SwiftUI
import EnergyKit

/// Top-level router. Decides between onboarding and the main app based on whether
/// HealthKit access has been requested yet, and owns the shared `AmperlyModel`.
struct RootView: View {
    @State private var model = AmperlyModel()
    @State private var didResolveAccess = false

    /// DEBUG-only screenshot mode: launching with `-uiPreview` boots straight
    /// into the main UI with sample data so the design can be reviewed without
    /// Health access. Compiled out of Release builds entirely.
    private var isUIPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-uiPreview")
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if isUIPreview {
                MainTabView()
            } else if !didResolveAccess {
                LaunchPlaceholder()
            } else if model.hasRequestedHealthAccess {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(isUIPreview ? AmperlyModel.preview : model)
        .background(Color.inkBase)
        .tint(Color.chargeMint)
        .preferredColorScheme(.dark)
        .task {
            guard !isUIPreview else { didResolveAccess = true; return }
            // Resolve onboarding-vs-main routing from the HealthKit actor first,
            // then pull the first snapshot if access was already requested.
            await model.refreshHealthAccessState()
            didResolveAccess = true
            if model.hasRequestedHealthAccess {
                await model.refresh()
            }
        }
    }
}

/// Neutral branded splash shown for the brief moment while we resolve whether
/// HealthKit access has been requested (avoids flashing onboarding on launch).
/// The bolt breathes in with a single, subtle scale-and-opacity pulse so the
/// beat before routing reads as intentional rather than a stall.
private struct LaunchPlaceholder: View {
    @State private var pulsed = false

    var body: some View {
        ZStack {
            DS.AmbientBackground()
            Image(systemName: "bolt.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(AmperlyTheme.energyGradient)
                .scaleEffect(pulsed ? 1.0 : 0.9)
                .opacity(pulsed ? 1.0 : 0.55)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2)) {
                        pulsed = true
                    }
                }
        }
    }
}

/// The two-tab home: the energy dashboard and settings. Both subviews are owned
/// by other agents; this file only references them by name.
struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Energy", systemImage: "bolt.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
