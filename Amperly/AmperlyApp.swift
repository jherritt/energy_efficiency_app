import SwiftUI

/// Amperly: a privacy-first energy app. Reads Apple Health live, computes
/// on-device, stores and transmits nothing. No account.
@main
struct AmperlyApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Background evaluation of the low-efficiency nudge (registration must
        // happen before the app finishes launching).
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Amperly is dark-only: the electric brand depends on it, and a
                // single appearance keeps every screen consistent.
                .preferredColorScheme(.dark)
                // Dark surface behind everything, ignoring safe areas so the
                // electric background bleeds edge to edge.
                .background(Color.inkBase.ignoresSafeArea())
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                BackgroundRefresh.schedule()
            }
        }
    }
}
