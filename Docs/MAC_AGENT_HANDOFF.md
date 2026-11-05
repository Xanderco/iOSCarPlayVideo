# Mac Agent Handoff: run it, make it green, ship it

These instructions are for an autonomous agent (or a person) on a Mac. The owner will say "run it". Your job is to make `Scripts/verify-all.sh` exit 0, finish the TODO tests listed below, complete the manual checklists, and log everything in the journal.

> **Status (2026-11-05 01:30 Bogotá), handoff task T1. Read this first.**
> This branch contains the docs, `Scripts/verify-all.sh` and `Makefile`, but **CI still runs the previous build+test steps**.
> The test suites, the app test hooks (`-uiTesting`, `-stubNetwork`, `-seedDemoData`, `StubNetwork`, `TestDataSeeder`), the `CarPlayInterfaceControlling` seam, the Favorites-sheet fix, the accessibility identifiers, `DashCastUITests` and the `project.yml` changes were written against the pre-redesign app. They live on branch **`claude/test-automation`** (commit `076f5b4`). In its last CI run, **155 of 156 tests passed** (unit 39, network 58, StoreKit 9, CarPlay 9, UI 19/20) and coverage was **65.67%**. The only failure was `PaywallUITests.testPurchaseUnlocksPro`: the query for the "Let's Drive!" success-alert button. The alert appears, but its button is not found by label. Query `app.alerts.firstMatch.buttons.firstMatch` instead, or add an identifier.
>
> **T1 = port `claude/test-automation` onto this branch.** After the phase 2–4 redesign (CarPlay emulator dropped, new Cast entry points, paywall `pro.lifetime`, `EntitlementGate`, onboarding notice), expect to:
> - Re-add the app hooks and identifiers to the new views.
> - Update `CastFlowUITests` and `PaywallUITests` (product id, gate), and handle the passenger notice in `DashCastUITestCase.launch()`.
> - Re-apply the `project.yml` changes: the `DashCastUITests` target, the `.storekit` file as a test resource, coverage, and the Run StoreKit config.
>
> Then switch `.github/workflows/ci.yml` to `Scripts/verify-all.sh` (copy it from that branch) and run until green. Until T1 is done, `verify-all.sh` fails at the **ui** phase ("0 tests executed") and possibly at storekit/carplay. That is expected; do not "fix" it by removing phases.

## 0. Rule #1: the journal
1. **Read `Docs/JOURNAL.md` before anything else.** It covers the vision, hard decisions **D1–D9 (do not reverse)**, open decisions O1…, and human to-dos.
2. **Before you finish** (and after each major milestone), append a dated Log entry at the top of the Log in Bogotá time. Cover what you changed, why, results (`verify-all.sh` summary table, test counts, coverage %), and follow-ups. Update "Next steps" and "Human to-dos" if they changed.

## 1. Prerequisites (one time)
```bash
xcode-select -p                          # must point at Xcode 26+ (Xcode.app from the App Store)
sudo xcode-select -s /Applications/Xcode.app
xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS         # iOS simulator runtime, if `xcrun simctl list runtimes` shows none
brew install xcodegen xcbeautify
```
The script checks all of this itself and prints the install command for anything that is missing.

## 2. Run
```bash
git checkout claude/ci-and-core-fixes && git pull
Scripts/verify-all.sh            # or: make verify   (≈10–20 min)
```
Useful variants (for iterating only; the final run must be the full one):
```bash
Scripts/verify-all.sh --only ui                 # one phase: unit | network | storekit | carplay | ui (comma-separated)
Scripts/verify-all.sh --skip-ui                 # everything except XCUITest
SIMULATOR_NAME="iPhone 17 Pro" Scripts/verify-all.sh
SIMULATOR_UDID=<udid> Scripts/verify-all.sh
Scripts/verify-all.sh --clean                   # wipe build/ first (stale DerivedData, odd linker errors)
```

## 3. Read failures
| Where | What |
|---|---|
| `build/reports/summary.txt` | Table of phases with pass/fail/skip counts and the coverage percentage. Start here. |
| `build/reports/logs/<phase>.log` | Raw xcodebuild output. Search for `error:` and `failed`. |
| `build/reports/results/<phase>.xcresult` | `open` it in Xcode to see the failing assertion, the console output, and UI-test screenshots at the moment of failure. |
| `build/reports/screenshots/` | Every screenshot attached by the UI tests (kept on success too). |
| `build/reports/junit/*.xml` | JUnit output for tools. |
| `build/reports/coverage.txt` | Coverage per target and per file, least-covered first. |

Phase meanings:
- **build**: compile or link error. Fix the code.
- **unit / network / storekit / carplay**: XCTest failures. The CarPlay phase uses `MockCarPlayInterfaceController` (no car needed). StoreKit uses `SKTestSession` with `DashCast/Resources/DashCastStore.storekit`.
- **ui**: XCUITest. The app is launched with `-uiTesting -stubNetwork` (fresh state, no animations, all HTTP goes to the in-app `StubNetwork` at `https://stub.dashcast.test`). Some tests add `-seedDemoData`.
- **coverage**: line coverage of `DashCast.app` across all phases. The minimum is `COVERAGE_MIN` in `Scripts/verify-all.sh`. **Raise it** as coverage grows. Never lower it to pass.

## 4. Fix-and-rerun loop rules
1. Run the full script → pick the **first** failing phase → read its log and xcresult.
2. Reproduce with `--only <phase>`, fix, re-run that phase, then re-run **everything**.
3. **Never** disable, skip (`XCTSkip`), delete, or weaken an assertion to get green (D9). A skipped test or a phase with 0 tests counts as a **failure**.
   If a test is genuinely wrong (e.g. a feature intentionally changed), fix the test and **justify it** in the commit message and the journal.
4. UI flakiness is a bug. Fix it with accessibility identifiers, `waitForExistence`, or the `waitFor/waitForLabel/waitForDisappearance` helpers. **No sleeps, no retries.**
5. No live network in tests. Add fixtures to `DashCast/App/TestSupport/StubNetwork.swift` (UI tests) or inject a `URLProtocol` stub session (unit tests).
6. Commit small and descriptive on `claude/<topic>`, open a PR into `claude/ci-and-core-fixes`, and wait for CI to be green. CI runs the same script.

## 5. Signing notes
- Team ID **96YG38576A**, automatic signing, bundle id `com.xanderco.dashcast`.
- **Tests and simulator builds run with `CODE_SIGNING_ALLOWED=NO`**. `verify-all.sh` passes it, so no certificates are needed.
- A real device or TestFlight needs Xcode signed into the owner's Apple ID (Xcode ▸ Settings ▸ Accounts) and a provisioning profile with the required capabilities. The CarPlay entitlement (`com.apple.developer.carplay-*`) only exists **after Apple grants it**. Until then, CarPlay appears only in the CarPlay Simulator, and device builds must not include the entitlement.

## 6. TODO tests (features that landed after this harness, or not yet covered)
Add these as each feature lands on `claude/ci-and-core-fixes`. Each item needs a unit test and/or a UI smoke test.
- [ ] **Passenger safety notice / onboarding** (`PassengerSafetyNotice`, id `passengerNoticeAccept`; from the Territory-removal PR #21): UI test that it shows on first launch without `-seedDemoData` and that Accept dismisses it and does not show again. Note that `-uiTesting` wipes defaults, so the notice will appear in every UI test once #21 lands. Either make `DashCastUITestCase.launch()` accept it when present (wait for `passengerNoticeAccept` and tap it), or add a `-skipSafetyNotice` argument and test the notice separately.
- [ ] **Jellyfin/Emby add server** (#19, `MediaServerViews`, ids `addMediaServerButton`, `mediaServerAddressField`, `mediaServerUsernameField`, `mediaServerPasswordField`, `mediaServerConnectButton`): add `StubNetwork` fixtures for `/System/Info/Public`, `/Users/AuthenticateByName`, `/Users/{id}/Views` and `/Items` under `stub.dashcast.test`, plus a UI test that adds a server and browses the library. `MediaServerClientTests` already runs in the **network** phase.
- [ ] **QR import screen** (`PlaylistQRImportView`, ids `scanPlaylistQRButton`, `qrManualLinkField`, `qrImportSuccess`): the simulator has no camera, so the view falls back to manual entry. UI test: open the screen, enter `https://stub.dashcast.test/playlist.m3u`, expect `qrImportSuccess`. Only a real device can test the camera.
- [ ] **Paywall product id** (D1 says `pro.lifetime`): when the paywall PR changes the id, update `DashCastStore.storekit`. `PaywallUITests.testRestoreFindsEarlierPurchase` buys `"com.dashcast.lifetime"` by literal id, so change that string too. Unit tests use `StoreKitManager.lifetimeProductID`. Also add `EntitlementGate` free-tier limit tests.
- [ ] **Mini player / car mode redesign (2A/2B)**: keep or move the identifiers `Cast_MiniPlayer`, `Player_Title`, `Player_PlayPause` and `Cast_CarPlayModeButton`. If the redesign changes screens, update `CastFlowUITests`.
- [ ] **Core bugfixes (#18)**: the local "Your Videos" list, `VideoPlayerService.stop()`, and the external display scene. Unit tests are in `CoreBugfixTests`. Add a UI test for the local videos list using `-seedDemoData`, which could seed a local video copied from the bundle.
- [ ] **Car video output / broadcast extension**: unit-test whatever logic is added. The broadcast itself is manual (see 7.4).
- [ ] **Browser Send to car with a real page**: `WKWebView` does not use `URLProtocol`. Add a test that loads a local HTML file (bundle a `video.html` with `<video src=file://…>`), taps Send to car, and expects "Sent to DashCast". `WebVideoExtractorTests` already covers the parsing.
- [ ] Raise `COVERAGE_MIN` (now 60%; first measured run 65.67%) as these land.

## 7. Manual-only checks (cannot run in CI)
Record the results (pass/fail, device, iOS version, notes) in the journal Log.

### 7.1 Real iPhone
1. Connect the iPhone, select it in Xcode, run the **DashCast** scheme (signing: team 96YG38576A).
2. First launch: the safety notice appears. Accept it.
3. Cast ▸ Media Source ▸ + Add Playlist ▸ From URL: paste a real M3U link. The channels appear. Play one. The mini player shows, and play/pause works.
4. Local Videos: import a video from Photos. It plays.
5. Favorites: heart a channel. It appears in the Favorites sheet.
6. Paywall: shows USD 19.99 (sandbox account). Buy, delete the app, reinstall, Restore. Pro is unlocked again.
7. Lock the screen while audio plays. Audio continues, and the lock-screen controls work.
8. Me ▸ Settings: every link opens (privacy, terms, restore, rate, share).

### 7.2 CarPlay Simulator (Xcode ▸ Open Developer Tool ▸ CarPlay Simulator, or Simulator ▸ I/O ▸ External Displays ▸ CarPlay)
1. Run the app in the iOS Simulator, then open the CarPlay window.
2. DashCast shows Library / Favorites / Info tabs. Library lists the playlist groups.
3. Open a group, then a channel. Now Playing shows the title. Play/pause from CarPlay works.
4. Favorite a channel on the phone. The CarPlay Favorites tab updates without relaunching.
5. Push deeply (group → channel → back, repeat). No crash (the template depth limit is 5).
6. Disconnect and reconnect CarPlay. No crash.

### 7.3 AirPlay to the car / TV (passengers or while parked only)
1. Play a channel, then tap the AirPlay button in Cast and pick an Apple TV or AirPlay head unit.
2. Video plays on the external screen, and the iPhone shows the external-display state.
3. Unplug or disconnect. Playback returns to the phone without a crash.
4. USB-C/HDMI adapter: same check through `ExternalDisplayManager`.

### 7.4 Broadcast / screen mirroring
1. If a Broadcast Upload extension exists: Control Center ▸ long-press Screen Recording ▸ DashCast. The broadcast starts and stops cleanly.
2. Otherwise: Cast ▸ Mirror iPhone shows instructions, and Control Center ▸ Screen Mirroring works with an AirPlay receiver.

### 7.5 TestFlight
1. Bump `CFBundleVersion` in `DashCast/Info.plist`.
2. Product ▸ Archive ▸ Distribute ▸ App Store Connect ▸ Upload, or use `.github/workflows/testflight.yml` if its secrets are set (`Docs/QA/testflight.md`).
3. In App Store Connect, add internal testers, and fill in the review notes (demo playlist, passenger-only statement).
4. Install from TestFlight on the owner's phone and repeat 7.1 steps 2–6.
5. **In a real car** (parked): 7.3 and, if the entitlement is granted, 7.2 on the head unit.

## 8. Definition of Done
- [ ] `Scripts/verify-all.sh` exits **0** on the Mac with a full run (no `--skip-ui`, no `--only`).
- [ ] CI (`DashCast CI` / verify-all) is green on the PR into `claude/ci-and-core-fixes`.
- [ ] Coverage is at or above `COVERAGE_MIN`, and the threshold was raised if coverage went up.
- [ ] Zero skipped tests, and no test was disabled or weakened (D9).
- [ ] The section 6 TODO tests are written for every feature present on the branch.
- [ ] The section 7 manual checklists are done, with results logged.
- [ ] A `Docs/JOURNAL.md` Log entry has the summary table, test counts, coverage, and follow-ups, and Next steps / Human to-dos are updated.
