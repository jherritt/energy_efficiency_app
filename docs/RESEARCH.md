# The science behind Amperly's scoring model

Summary of the research pass (June 2026) that shaped v1.1 of the engine, and how
each finding maps to code. All processing remains on-device and read-only.

## How Amperly compares to the leaders

Amperly's charge-once-overnight / drain-through-the-day structure matches Garmin
Body Battery (Firstbeat); its charge inputs match the readiness cohort (Oura
Readiness, Whoop Recovery): sleep duration, deep+REM share, sleep efficiency,
overnight HRV and resting heart rate versus a personal baseline, and schedule
regularity. Treating missing data as neutral (never a penalty, never a
fabricated score) matches how Oura/Fitbit/Google withhold rather than invent.

Two divergences were found and fixed in v1.1:

1. Autonomic recovery was under-weighted. The recovery multiplier band widened
   from 0.92-1.08 to 0.88-1.10, and two downside-only illness guards were added,
   matching the Whoop/Oura signal set:
   - Overnight wrist temperature above the personal baseline
     (`appleSleepingWristTemperature`): each 0.5 C past a 0.5 C threshold costs
     3%, floored at 0.90. Running cool is never rewarded.
   - Overnight respiratory rate above baseline (`respiratoryRate`): each
     breath/min past a 1.5 threshold costs 2%, floored at 0.90.
2. No cumulative training-load term. Added an acute:chronic workload ratio
   (7-day vs 28-day mean active energy, the ACWR pattern used by Samsung, Oura
   Activity Balance, and Whoop Strain): a ratio above 1.3 trims the morning
   charge linearly, capped at 5 points at a ratio of 1.7. No new permissions.

## Sleep debt (Van Dongen 2003; RISE-style backlog)

Chronic sleep restriction accumulates near-linearly over about two weeks, and
recovery is slow and partial. The v1.1 model (`ScoringEngine.sleepDebt`):

- 14-night window, excluding last night (it is already priced into the acute
  morning charge; including it would double-count).
- Each night the balance decays by 0.84 (half-life about 4 nights), then a short
  night adds its shortfall linearly.
- Oversleep pays down at 0.5:1, at most 2 credited hours per night - one long
  lie-in cannot wipe a backlog.
- Balance clamped to 0-20h; battery penalty 2%/h capped at 15 points, so RISE's
  5h "acceptable ceiling" costs a moderate 10 and the cap is reserved for
  genuinely severe debt. Steady 6h nights for two weeks converge to ~11.4h of
  debt, consistent with the literature's "equivalent of one to two nights of
  total deprivation."

## When sleep is not recorded

Never assume zero sleep (false crater) and never assume a perfect night:

- Tier B1 (preferred): the median of the user's recent measured morning charges
  minus a flat 5-point low-confidence haircut. Median is robust to one outlier.
- Tier B2: the 7-day average night through the duration formula, discounted 0.85.
- Tier C (brand-new user): boot at 72, not the 50 midpoint - leaders start
  neutral-high and do not penalize an empty history.
- Every estimated day is flagged (`DayScore.batteryIsEstimated`) and labeled in
  the UI.

## Efficiency chart (Tesla-style)

The intraday chart reconstructs the day through the same engine as the hero
number (`ScoringEngine.daySeries`), so the curve and the score always agree.
Design follows the Tesla energy-graph pattern: smoothed line over a gradient
area fill, one dashed personal-average reference line, fixed 0-100 domain so
day-to-day shapes are comparable, and a marked "now" point.

## Deferred (documented, not yet shipped)

- VO2 Max-personalized drain intensity (`vo2Max`)
- Mindful-session daytime recharge (`mindfulSession`) - structural change,
  needs validation that the battery cannot drift upward unrealistically
- Sleeping breathing disturbances (iOS 18+ hardware-gated)
- Blood oxygen as a secondary illness flag (overlaps the shipped guards)
- EDA/stress-based drain: impossible on iOS - Apple exposes no EDA HealthKit type
