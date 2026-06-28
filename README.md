# Amperly

Amperly is a privacy-first iOS app that turns your Apple Health data into a single, intuitive picture of your day: a glowing **battery** that is charged by sleep and drained as you move through your day, a **points** ledger for the habits that matter, and one hero **efficiency** score out of 100 that tells you how well you spent your energy.

Everything is read live from Apple Health, computed entirely on device, and never stored or transmitted. There is no account, no sign-in, and no server.

---

## What Amperly shows

- **Battery** — Your morning charge comes from last night's sleep. As the day goes on, activity and time spent draw it down. When the battery drops below 15 percent it shifts toward a warning tint so you can see depletion at a glance.
- **Points today** — Credit for Move, Exercise, and Stand goals, plus on-time bedtime, on-time wake, and hydration. The ledger shows what you have earned and what is still available.
- **Efficiency** — A hero score out of 100 that summarizes how effectively the energy you had was spent against your targets. When Health is not authorized, or the underlying values are unavailable, the app renders `--` rather than a misleading zero.

---

## Architecture

Amperly is a small, focused workspace built around one verified core package and two app-layer targets.

### EnergyKit (Swift package)

The shared, unit-verified core. It contains:

- **ScoringEngine** — A pure, deterministic scoring engine. Given a `HealthSnapshot` and a set of `UserTargets`, it produces a `DayScore` (battery, energy spent, efficiency, points breakdown, XP). It also computes `Progression` from a history of day scores (level, XP into level, points streak, sleep streak).
- **HealthKitService** — An `actor` that reads Apple Health **read-only**. It requests authorization, builds the current `HealthSnapshot`, and assembles recent day scores. It reads sleep, activity (active and basal energy, steps, exercise minutes, stand hours), heart rate and HRV, hydration, daylight, and caffeine timing.
- **Models** — `HealthSnapshot`, `SleepData`, `WorkoutSummary`, `Baseline`, `UserTargets`, `PointsBreakdown`, `DayScore`, `Progression`, and the `ScoringConstants` enum of tunable values.

EnergyKit holds no user data of its own. It transforms a snapshot into a score and hands it back. Nothing is persisted inside the package.

### Amperly (app target)

The SwiftUI app. It renders the battery, the points ledger, and the efficiency score in a dark-first electric theme (with light mode support), and drives `HealthKitService` for live reads. Health values flow straight from the snapshot into the view and are discarded when the view goes away.

### AmperlyWidget (widget extension)

A WidgetKit extension that surfaces the battery and efficiency score on the Home Screen, Lock Screen, and in StandBy. It uses the same EnergyKit scoring path, so the widget and the app always agree.

### Data lifecycle

All data is **ephemeral and on-device**. Amperly reads from Apple Health on demand, computes a score in memory, displays it, and lets it go. There is no database, no cache of health values written to disk, no analytics, and no network calls carrying personal data. The app functions with no account and no connectivity.

---

## Requirements

- Xcode 16 or newer (Swift 6 toolchain)
- iOS 17.0 or newer device or simulator
- An Apple Developer account for running on a physical device (HealthKit requires a provisioning profile with the HealthKit capability)
- [XcodeGen](https://github.com/yonsm/XcodeGen) to generate the project

---

## How to open and run

The Xcode project is generated from a project spec with XcodeGen, so the repository stays clean of generated `.xcodeproj` churn.

1. Install XcodeGen and generate the project:

   ```sh
   brew install xcodegen
   xcodegen generate
   ```

2. Open the generated project:

   ```sh
   open Amperly.xcodeproj
   ```

3. In Xcode, select the **Amperly** target, open **Signing and Capabilities**, and set your **Signing Team**.
4. Choose an **iOS 17** simulator or a connected iOS 17 device.
5. Press **Run**.

On first launch Amperly asks for permission to read Apple Health. Grant the categories you are comfortable with. The richer the data you allow (especially sleep), the more complete the battery and efficiency picture. Anything you do not grant simply renders as `--`.

> Note: the iOS Simulator has limited Health data. For a realistic battery and efficiency score, run on a device that has been logging sleep and activity.

---

## Scoring model summary

Amperly's model is built on three ideas that map directly to the UI.

1. **Charge from sleep.** Last night's sleep sets your **morning battery**. Sleep duration relative to your sleep target, plus sleep quality signals (efficiency, deep and REM share), determine how full you start the day.
2. **Drain across the day.** Energy spent — active and basal energy expenditure over the day so far — draws the battery down from its morning charge against a daily energy budget. This produces the **current battery**.
3. **Efficiency out of 100.** Efficiency rewards spending the energy you had on the things that count — hitting Move, Exercise, and Stand goals, keeping a consistent on-time bedtime and wake, and staying hydrated — rather than simply burning the most calories. It is a quality measure, not a volume measure.

Points and XP run alongside the battery. Each habit contributes points up to a per-category maximum; XP accrues from points and feeds `Progression` (level, points streak, sleep streak). All thresholds and maximums live in `ScoringConstants` so the model is tunable in one place.

Optional values are honored throughout: `morningBattery`, `currentBattery`, and `efficiency` are optionals, and `nil` means Health was not authorized or the value is unavailable. The UI shows `--` in that case and never substitutes `0`.

### Scoring at a glance

| Concept | Source | Where it shows |
|---|---|---|
| Morning battery | Last night's sleep vs. sleep target and quality | Battery fill at start of day |
| Current battery | Morning battery minus energy spent vs. daily budget | Battery fill now (warning tint below 15%) |
| Energy spent | Active plus basal energy so far today | Drain on the battery |
| Move / Exercise / Stand points | Activity goals vs. targets | Points ledger |
| Bedtime / Wake points | On-time vs. bed and wake targets, within the on-time window | Points ledger |
| Hydration points | Water intake vs. water goal | Points ledger |
| Efficiency | How well available energy was spent against targets | Hero score out of 100 |
| XP, level, streaks | Accumulated points and consistency over history | Progression |

---

## Privacy

Amperly collects nothing. It reads Apple Health read-only, with your permission, processes everything on device, and stores or transmits nothing. There are no analytics, ads, or tracking SDKs. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for the full plain-language policy and [SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md) for App Store submission steps.

---

## Bundle identifiers

- App: `com.amperly.Amperly`
- Widget: `com.amperly.Amperly.AmperlyWidget`

Deployment target: iOS 17.0.
