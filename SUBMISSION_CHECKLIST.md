# Amperly App Store Submission Checklist

This is a step-by-step guide for shipping Amperly to the App Store, written for someone who has never submitted an app before. Work through it in order. Each step is concrete; where a decision is needed, the safe default for Amperly is given.

---

## 0. Confirm the name is clear

Before investing in the name "Amperly," make sure it is available and not infringing.

- **Trademark search:** Search the USPTO Trademark Electronic Search System (TESS) at the United States Patent and Trademark Office website for "Amperly" and close variants. Look for live marks in software, health, or fitness classes (especially International Classes 9 and 42). If a confusingly similar live mark exists in those classes, choose a different name.
- **App Store search:** In the App Store and in App Store Connect, search "Amperly" to confirm no existing app uses the name. App names must be unique across the store.
- **Domain and handle (optional but wise):** Check that a matching support domain or social handle is available, since you will need a support URL later.

If anything is unclear, pick a distinct name now. Renaming after launch is costly.

---

## 1. Install the full Xcode

- Install **Xcode** from the Mac App Store (the full app, not just the command line tools).
- Open it once and let it install additional components when prompted.
- Confirm it includes the iOS 17 SDK or later.

---

## 2. Enroll in the Apple Developer Program

- Go to the Apple Developer website and enroll in the **Apple Developer Program**. The cost is **99 USD per year**.
- Enrollment can take from a few hours to a couple of days to be approved.
- You cannot submit to the App Store without an active membership.

---

## 3. Open the project and configure signing

- Generate the Xcode project if you have not already: `brew install xcodegen && xcodegen generate`, then `open Amperly.xcodeproj`.
- Select the **Amperly** target, go to **Signing and Capabilities**, and set your **Signing Team** to your developer account.
- The default bundle identifier is `com.amperly.Amperly` (widget: `com.amperly.Amperly.AmperlyWidget`). If `com.amperly.Amperly` is already taken in your account or on the store, change it to a unique identifier you own (for example, `com.yourname.Amperly`) and update the widget identifier to match (`<your-app-id>.AmperlyWidget`).
- Let Xcode create the provisioning profiles automatically.

---

## 4. Confirm the HealthKit capability

- The **HealthKit** capability is already declared in the app's entitlements, and the project includes the required Health usage description strings.
- Verify under **Signing and Capabilities** that HealthKit appears for the Amperly target. You do not need to add it manually.
- Amperly only reads from HealthKit, so no "clinical health records" or write permissions are required.

---

## 5. Bump the version and build number

- Set the **marketing version** to `1.0` for the first release.
- Set the **build number** to `1` (increment the build number for every upload you make to App Store Connect, even small re-uploads).

---

## 6. Archive and validate

- In Xcode, set the run destination to **Any iOS Device (arm64)**.
- Choose **Product > Archive**. Wait for the archive to complete.
- In the Organizer window that appears, select the archive and click **Validate App**. Fix any issues it reports.
- Once validation passes, click **Distribute App** and upload to App Store Connect.

---

## 7. Create the app record in App Store Connect

- Sign in to App Store Connect and create a **new app**.
- Enter the **name** (`Amperly`), **primary language**, **bundle ID** (matching step 3), and an SKU (any unique internal string).
- Fill in the listing fields:
  - **Subtitle:** from `AppStore/metadata/subtitle.txt`.
  - **Category:** Primary **Health and Fitness**, Secondary **Lifestyle** (see `AppStore/metadata/categories.txt`).
  - **Privacy Policy URL:** the public URL where you host `PRIVACY_POLICY.md`.
  - **Support URL:** a page where users can reach you (can be a simple site or a contact page).

---

## 8. Complete the App Privacy questionnaire

- In App Store Connect, open **App Privacy**.
- Answer that you do **not** collect data. Amperly's correct answer is **Data Not Collected**.
- Use `AppStore/metadata/privacy_label.txt` as your reference. The key point: HealthKit data is read on-device, read-only, and never stored, transmitted, or used for tracking or advertising.

---

## 9. Upload screenshots

- Upload the **6.7-inch** screenshots from `AppStore/screenshots`.
- The 6.7-inch set generally satisfies the requirement for the larger iPhone sizes; the **6.5-inch** slot can reuse or scale the same images if a separate set is requested.
- Make sure captions and on-screen text contain **no emoji**.

---

## 10. Paste the metadata

- Copy the listing text from `AppStore/metadata`:
  - **Description:** `description.txt`
  - **Keywords:** `keywords.txt`
  - **Promotional text:** `promotional_text.txt`
  - **What's New:** `whats_new.txt`
- Paste each into the matching field in App Store Connect.

---

## 11. Answer the Health data review note

In the **App Review Information > Notes** field, explain clearly how Amperly uses Health data. Suggested note:

> Amperly reads Apple Health data (sleep, activity, heart rate and HRV, hydration, time in daylight, and caffeine timing) on a read-only basis, with the user's permission. All processing happens on device in real time to display a daily energy battery, a points ledger, and an efficiency score. No health data is stored, cached to disk, transmitted off the device, sold, shared, or used for advertising. There is no account and no server. Users can revoke access at any time in Settings > Privacy and Security > Health.

Providing this note up front reduces back-and-forth with the review team.

---

## 12. Submit for review

- Attach the uploaded build to the version.
- Set pricing to **Free** (Amperly has no in-app purchases or ads).
- Confirm export compliance (Amperly does not use non-exempt encryption; answer accordingly).
- Click **Add for Review**, then **Submit for Review**.

---

## Common rejection pitfalls for HealthKit apps, and how Amperly avoids them

HealthKit apps are reviewed carefully. These are the issues that most often cause rejections, and how Amperly is built to pass.

- **Storing or transmitting Health data to a server.** Apple prohibits storing HealthKit data in iCloud or sending it to third-party servers for purposes the user did not consent to. *Amperly stores and transmits nothing; all computation is on device.*
- **Using Health data for advertising or sharing it with data brokers.** Strictly forbidden. *Amperly has no ads, no analytics, no tracking SDKs, and never uses Health data for advertising.*
- **Missing or vague Health usage description strings.** The purpose strings must clearly explain why each data type is read. *Amperly includes clear, specific read usage descriptions.*
- **Requesting Health permissions but not using the data in a visible way.** Apple rejects apps that ask for Health access without obvious in-app value. *Amperly's entire interface is driven by the Health data it reads: the battery, points, and efficiency score.*
- **Crashing or showing misleading values when permission is denied.** Apps must handle the no-permission state gracefully. *Amperly renders `--` for any value it cannot read and never substitutes a zero.*
- **Privacy policy that does not match behavior, or a missing policy URL.** The policy must be accurate and reachable. *Amperly's policy states it collects nothing, which matches the app exactly; host `PRIVACY_POLICY.md` at a stable URL.*
- **Declaring the wrong App Privacy answers.** Mismatched answers trigger rejection. *Amperly answers "Data Not Collected," which is accurate.*
- **Inappropriate Health entitlements.** Requesting write access or clinical records you do not use raises flags. *Amperly requests read-only access to only the categories it displays.*

Work through the checklist in order, keep the review note clear, and Amperly's privacy-first design should make the review straightforward.

---

## Provided assets reference

- **Screenshots:** `AppStore/screenshots/` holds the six 6.7-inch frames (1290 x 2796). `AppStore/screenshots/6.5inch/` holds the same six at 1242 x 2688 for the 6.5-inch size if your listing asks for it.
- **App Review notes:** paste `AppStore/metadata/app_review_notes.txt` into App Store Connect under App Review Information, Notes. It pre-answers the common HealthKit review questions.
- **Metadata:** name, subtitle, promotional text, description, keywords, what's new, categories, and the privacy label text are all in `AppStore/metadata/`.

---

## Optional: ship the Apple Watch app + complication

The project includes an Apple Watch app (`AmperlyWatch/`) and a watch complication (`AmperlyWatchWidget/`) that show the same battery and efficiency, reading Apple Health on the watch and storing nothing. They reuse the verified `EnergyKit` engine.

By default these are **not embedded** in the iPhone app, so the iPhone scheme builds and ships without them. To include the watch app in your release:

1. Open `project.yml` and find the `Amperly` target's `dependencies:` list.
2. Add the watch app as an embedded dependency:
   ```yaml
       - target: AmperlyWatch
         embed: true
   ```
3. Regenerate the project: `xcodegen generate`.
4. In Xcode, select the `AmperlyWatch` scheme and build it once against a watchOS 10 simulator to confirm it compiles on your toolchain, then archive the iPhone app as usual; the watch app rides along in the same submission.

If you prefer to ship the iPhone app alone for v1, do nothing; the watch targets simply sit unused.
