//
//  AmperlyWatchApp.swift
//  Amperly Watch App
//
//  Minimal watchOS host app for the Amperly complications. Shows the battery and
//  efficiency, and requests HealthKit read access. Reads live, stores nothing.
//

import SwiftUI

@main
struct AmperlyWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
