import SwiftUI
import EnergyKit

/// Top-level router. Decides between onboarding and the main app based on whether
/// HealthKit access has been requested yet, and owns the shared `AmperlyModel`.
struct RootView: View {
    @State private var model = AmperlyModel()

    var body: some View {
        Group {
            if model.hasRequestedHealthAccess {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(model)
        .background(Color.inkBase)
        .tint(Color.chargeMint)
        .task {
            // First paint: pull a snapshot if we already have (or were denied) access.
            if model.hasRequestedHealthAccess {
                await model.refresh()
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
