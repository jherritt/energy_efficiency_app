//
//  WatchModel.swift
//  Amperly Watch App
//
//  Drives the watch UI from EnergyKit. Reads a live, ephemeral HealthKit snapshot
//  and scores it on-device. Nothing is persisted or transmitted.
//

import Foundation
import Observation
import EnergyKit

@MainActor
@Observable
final class WatchModel {
    var score: DayScore?
    var isRefreshing = false

    /// Request HealthKit access on first appearance, then refresh.
    func requestAccessAndRefresh() async {
        try? await HealthKitService.shared.requestAuthorization()
        await refresh()
    }

    /// Pull a fresh snapshot and score it. Falls back to the unauthorized
    /// placeholder so the UI shows "--" rather than fabricated numbers.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let now = Date()
        let snapshot = await HealthKitService.shared.currentSnapshot(now: now)
        score = snapshot.isAuthorized ? ScoringEngine.score(snapshot) : .unauthorized(date: now)
    }
}
