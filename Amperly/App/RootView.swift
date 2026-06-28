import SwiftUI
import EnergyKit

/// Top-level router. Decides between onboarding and the main app based on whether
/// HealthKit access has been requested yet, and owns the shared `AmperlyModel`.
struct RootView: View {
    @State private var model = AmperlyModel()
    @State private var didResolveAccess = false

    var body: some View {
        Group {
            if !didResolveAccess {
                LaunchPlaceholder()
            } else if model.hasRequestedHealthAccess {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(model)
        .background(Color.inkBase)
        .tint(Color.chargeMint)
        .task {
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
private struct LaunchPlaceholder: View {
    var body: some View {
        ZStack {
            Color.inkBase.ignoresSafeArea()
            Image(systemName: "bolt.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(AmperlyTheme.energyGradient)
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
