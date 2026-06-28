import XCTest
@testable import EnergyKit

/// Verifies the engine reproduces the documented worked example and edge cases.
final class ScoringEngineTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }()

    private func today(_ hour: Int, _ minute: Int) -> Date {
        let start = cal.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        return cal.date(byAdding: DateComponents(hour: hour, minute: minute), to: start)!
    }

    private func sleep75() -> SleepData {
        SleepData(asleep: 7.5 * 3600, bedTime: today(23, 20), wakeTime: today(7, 10))
    }

    func testMorningBatteryNeutral() {
        let snap = HealthSnapshot(sleep: sleep75(), asOf: today(7, 10))
        let morning = ScoringEngine.morningBattery(snapshot: snap, targets: .default)
        XCTAssertNotNil(morning)
        XCTAssertEqual(morning!, 94.6875, accuracy: 0.05)
    }

    func testMiddayEfficiencyPinnedAt100() {
        let snap = HealthSnapshot(sleep: sleep75(),
                                  activeEnergyKcal: 300, exerciseMinutes: 22, standHours: 7,
                                  waterML: 1200, asOf: today(15, 10))
        let score = ScoringEngine.score(snap)
        XCTAssertEqual(score.energySpent, 42.0, accuracy: 0.01)
        XCTAssertEqual(score.currentBattery!, 52.6875, accuracy: 0.05)
        XCTAssertEqual(score.points.total, 70.4167, accuracy: 0.01)
        XCTAssertEqual(score.efficiency!, 100.0, accuracy: 0.001)
    }

    func testEndOfDayEfficiency() {
        let snap = HealthSnapshot(sleep: sleep75(),
                                  activeEnergyKcal: 520, exerciseMinutes: 35, standHours: 11,
                                  waterML: 1800, asOf: today(22, 30))
        let score = ScoringEngine.score(snap)
        XCTAssertEqual(score.energySpent, 77.2, accuracy: 0.05)
        XCTAssertEqual(score.points.total, 96.75, accuracy: 0.01)
        XCTAssertEqual(score.efficiency!, 97.76, accuracy: 0.2)
    }

    func testDawnFloorStabilizesHero() {
        let snap = HealthSnapshot(sleep: sleep75(), asOf: today(8, 0))
        let score = ScoringEngine.score(snap)
        XCTAssertEqual(score.points.total, 20.0, accuracy: 0.001) // sleep points only
        XCTAssertEqual(score.efficiency!, 100.0, accuracy: 0.001) // floor keeps it sane
    }

    func testNoSleepDataRescales() {
        let snap = HealthSnapshot(sleep: nil, activeEnergyKcal: 250, asOf: today(15, 0))
        let score = ScoringEngine.score(snap)
        XCTAssertFalse(score.hasSleepData)
        XCTAssertEqual(score.morningBattery!, 50.0, accuracy: 0.001)
        XCTAssertEqual(score.points.maxAvailable, 80.0, accuracy: 0.001)
        XCTAssertEqual(score.points.bedtime, 0.0, accuracy: 0.001)
    }

    func testUnauthorizedReturnsPlaceholders() {
        let snap = HealthSnapshot(isAuthorized: false, asOf: today(12, 0))
        let score = ScoringEngine.score(snap)
        XCTAssertNil(score.morningBattery)
        XCTAssertNil(score.currentBattery)
        XCTAssertNil(score.efficiency)
    }

    func testOnTimeFade() {
        XCTAssertEqual(ScoringEngine.onTimeFade(0), 1.0, accuracy: 0.001)
        XCTAssertEqual(ScoringEngine.onTimeFade(30), 1.0, accuracy: 0.001)
        XCTAssertEqual(ScoringEngine.onTimeFade(60), 0.5, accuracy: 0.001)
        XCTAssertEqual(ScoringEngine.onTimeFade(90), 0.0, accuracy: 0.001)
        XCTAssertEqual(ScoringEngine.onTimeFade(120), 0.0, accuracy: 0.001)
    }

    func testDeviationWrapsMidnight() {
        let late = today(23, 50)
        let dev = ScoringEngine.deviationMinutes(date: late, target: DateComponents(hour: 0, minute: 10))
        XCTAssertEqual(dev, 20.0, accuracy: 0.001)
    }

    func testEnhancementsImproveCharge() {
        // A high-quality, well-recovered night should charge higher than neutral.
        var snap = HealthSnapshot(sleep: SleepData(inBed: 8 * 3600, asleep: 7.5 * 3600,
                                                   deep: 1.6 * 3600, rem: 1.6 * 3600, core: 4.3 * 3600,
                                                   bedTime: today(23, 0), wakeTime: today(7, 0)),
                                  hrvSDNN: 70, restingHeartRate: 52, asOf: today(7, 0))
        snap.baseline = Baseline(hrvBaseline: 55, restingHeartRateBaseline: 58,
                                 sleepConsistencySDMinutes: 15)
        let morning = ScoringEngine.morningBattery(snapshot: snap, targets: .default)!
        XCTAssertGreaterThan(morning, 94.69) // beats the neutral example
        XCTAssertLessThanOrEqual(morning, 100.0)
    }

    func testLevelThresholds() {
        XCTAssertEqual(ScoringEngine.xpThreshold(forLevel: 1), 0, accuracy: 0.001)
        XCTAssertEqual(ScoringEngine.level(forXP: 0), 1)
        XCTAssertGreaterThanOrEqual(ScoringEngine.level(forXP: 5000), 2)
    }
}
