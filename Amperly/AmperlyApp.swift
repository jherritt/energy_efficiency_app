import SwiftUI

/// Amperly: a privacy-first energy app. Reads Apple Health live, computes
/// on-device, stores and transmits nothing. No account.
@main
struct AmperlyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // Support both light and dark; the theme is dark-first.
                .preferredColorScheme(nil)
                // Dark default surface behind everything, ignoring safe areas so
                // the electric background bleeds edge to edge.
                .background(Color.inkBase.ignoresSafeArea())
        }
    }
}
