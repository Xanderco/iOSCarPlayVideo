# Mac Agent Handoff: run it, make it green, ship it

These instructions are for an autonomous agent (or a person) on a Mac. The owner will say "run it". Your job is to make `Scripts/verify-all.sh` exit 0, finish the test checklists, complete the manual verifications, and log everything in the journal.

> **Status (2026-11-05), Base branch: `claude/classic-ui`. Read this first.**
> This repository uses `Scripts/verify-all.sh` (or `make verify`) as the single source of truth for build verification and automated tests.
> CI executes the build, unit, network, storekit, carplay, and UI test suites.
>
> **Architecture & Key Modules (Classic UI + CarPlay Video Mirror):**
> - **Classic UI Base:** 5 Native Tabs (`Cast`, `Drive`, `Widgets`, `Sounds`, `Me`) with Liquid Glass tab bar on iOS 26+ (classic capsule fallback on iOS 17).
> - **Video Engine:** AVPlayer, low-latency H.264 HLS encoding for CarPlay video mirror (`MirrorHLSEncoder`, `HLSSegmentStore`, `MirrorStreamServer`), bundled demo video player, M3U playlist store, Jellyfin/Emby client, QR code parser.
> - **Drive & Telemetry:** Native MapKit live tracking, telemetry G-force metrics, automatic drive detection (CoreMotion + speed), and trip replay (`TripReplayMapView`).
> - **CarPlay Scene:** Native CarPlay application templates (`CPTemplateApplicationSceneDelegate`, `CPDashboardController`). Entitlement request documented in `Docs/CarPlay.md` (`com.apple.developer.carplay-video`).
> - **Monetization & Entitlements:** StoreKit 2 lifetime pass ($19.99 `pro.lifetime`, non-consumable, Family Sharing enabled), zero subscriptions.
> - **Pre-Flight Hook & Automation:** `Scripts/verify-all.sh` runs prerequisite checks, project generation via `project.yml` (XcodeGen), build-for-testing, targeted test phases, code coverage enforcement, and artifact extraction.

---

## 1. Prerequisites (one-time on a new Mac)
```bash
sudo xcode-select -s /Applications/Xcode.app
xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS         # iOS simulator runtime, if `xcrun simctl list runtimes` shows none
brew install xcodegen xcbeautify
```
The script checks all of this itself and prints the install command for anything that is missing.

## 2. Run
```bash
git checkout claude/classic-ui && git pull
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
- **unit / network / storekit / carplay**: XCTest failures. The CarPlay phase uses `MockCarPlayInterfaceController` (no car needed).
- **ui**: XCUITest failure. Open the xcresult to see the screenshot taken at the exact failure line.
- **coverage**: line coverage dropped below threshold (`COVERAGE_MIN`, default 60%). Add tests for your changes.

## 4. Fix-and-rerun loop rules
1. Run the full script → pick the **first** failing phase → read its log and xcresult.
2. Reproduce with `--only <phase>`, fix, re-run that phase, then re-run **everything**.
3. **Never** disable, skip (`XCTSkip`), delete, or weaken an assertion to get green (D9). A skipped test or a phase with 0 tests counts as a **failure**.
   If a test is genuinely wrong (e.g. a feature intentionally changed), fix the test and **justify it** in the commit message and the journal.
4. UI flakiness is a bug. Fix it with accessibility identifiers, `waitForExistence`, or the `waitFor/waitForLabel/waitForDisappearance` helpers. **No sleeps, no retries.**
5. No live network in tests. Add fixtures to `DashCast/App/TestSupport/StubNetwork.swift` (UI tests) or inject a `URLProtocol` stub session (unit tests).
6. Commit small and descriptive on `claude/<topic>`, open a PR into `claude/classic-ui`, and wait for CI to be green. CI runs the same script.

## 5. Signing notes
- Team ID **96YG38576A**, automatic signing, bundle id `com.xanderco.dashcast`.
- **Tests and simulator builds run with `CODE_SIGNING_ALLOWED=NO`**. `verify-all.sh` passes it, so no certificates are needed.
- A real device or TestFlight needs Xcode signed into the owner's Apple ID (Xcode → Settings → Accounts) and a provisioning profile with the required capabilities. The CarPlay entitlement (`com.apple.developer.carplay-video`) only exists **after Apple grants it**. Until then, CarPlay appears only in the CarPlay Simulator, and device builds must not include the entitlement.

## 6. Test Suites & Coverage Checklist
- [x] **Passenger safety notice / onboarding** (`PassengerSafetyNotice`, `WelcomeOnboardingView`): verified via unit & UI flow.
- [x] **Media Server (Jellyfin / Emby)** (`MediaServerClientTests`, `MediaServerStoreTests`): tested in `network` phase with URLProtocol stubs.
- [x] **M3U / IPTV Parser** (`IPTVParserTests`, `PlaylistStoreTests`): tested in `network` phase.
- [x] **CarPlay Video Mirroring (HLS low-latency pipeline)** (`MirrorHLSTests`, `MirrorFrameTransportTests`): tested in `network` phase.
- [x] **StoreKit 2 lifetime pass** (`StoreKitTests`, `EntitlementGateTests`): tested in `storekit` phase against `DashCastStore.storekit`.
- [x] **CarPlay scene** (`CarPlaySceneTests`, `CarPlayDiagnosticTests`): tested in `carplay` phase.
- [x] **Drive & Telemetry** (`DriveTelemetryTests`, `TripDetectionTests`): tested in `unit` phase.
- [x] **UI smoke tests** (`DashCastSmokeUITests`): tested on booted iOS simulator.

## 7. Manual-only checks (cannot run in CI)
Record the results (pass/fail, device, iOS version, notes) in the journal Log.

### 7.1 Real iPhone
1. Connect the iPhone, select it in Xcode, run the **DashCast** scheme (signing: team 96YG38576A).
2. First launch: the safety notice appears. Accept it.
3. Cast → Media Source → + Add Playlist → From URL: paste a real M3U link. The channels appear. Play one. The mini player shows, and play/pause works.
4. Local Videos: import a video from Photos. It plays.
5. Favorites: heart a channel. It appears in the Favorites sheet.
6. Paywall: shows USD 19.99 (sandbox account). Buy, delete the app, reinstall, Restore. Pro is unlocked again.
7. Lock the screen while audio plays. Audio continues, and the lock-screen controls work.
8. Me → Settings: every link opens (privacy, terms, restore, rate, share).

### 7.2 CarPlay Simulator (Xcode → Open Developer Tool → CarPlay Simulator, or Simulator → I/O → External Displays → CarPlay)
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

### 7.4 Broadcast / screen mirroring (CarPlay Video Mirror)
1. ReplayKit Broadcast: Control Center → long-press Screen Recording → DashCast. Low-latency HLS server serves video at `http://127.0.0.1:8088/hls/live.m3u8`.
2. CarPlay display renders the live stream via AVPlayer.

### 7.5 TestFlight
1. Bump `CFBundleVersion` in `DashCast/Info.plist`.
2. Product → Archive → Distribute → App Store Connect → Upload, or use `.github/workflows/testflight.yml` if its secrets are set (`Docs/QA/testflight.md`).
3. In App Store Connect, add internal testers, and fill in the review notes (demo playlist, passenger-only statement).
4. Install from TestFlight on the owner's phone and repeat 7.1 steps 2–6.
5. **In a real car** (parked): 7.3 and, once the entitlement is granted, 7.2 on the head unit.

## 8. Definition of Done
- [ ] `Scripts/verify-all.sh` exits **0** on the Mac with a full run (no `--skip-ui`, no `--only`).
- [ ] CI is green on GitHub Actions.
- [ ] PR link and CI run link posted in issue comment.
- [ ] Journal Log entry appended to `Docs/JOURNAL.md`.
