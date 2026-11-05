# Manual smoke test (on device)

Run this checklist on a physical iPhone with every TestFlight build before handing it to
testers. CI already covers launch, tab switching, the Media Sources sheet and the Browser
sheet in the simulator (`DashCastUITests`, with screenshots in the `ui-test-screenshots` artifact).
This list covers what the simulator can't: real playback, AirPlay, permissions, sensors, CarPlay, and low-latency HLS video mirroring.

**Build:** ______ **Device / iOS:** ______ **Tester:** ______ **Date:** ______

Mark each item ✅ pass, ❌ fail (file a bug with a screenshot), or ⏭ not tested.

## 0. Install & launch
- [ ] The TestFlight build installs and the icon and name read "DashCast".
- [ ] A cold launch lands on the **Cast** tab in under 3 s with no crash.
- [ ] Passenger Safety Notice appears on first launch; tapping Accept dismisses it and persists across launches.
- [ ] The app stays in dark mode. The native tab bar shows Cast, Drive, Widgets, Sounds, and Me.
- [ ] Turning to landscape and back keeps the layout intact.
- [ ] Background the app, then reopen it after 1 min. The state is preserved.

## 1. Cast tab
- [ ] **Media Source** opens the "Media Sources" sheet, which lists bundled sample channels.
- [ ] Tapping a sample channel closes the sheet and starts playback in the inline player.
- [ ] Fullscreen toggle, pause/play and scrubbing work. Audio plays with the silent switch on (audio session).
- [ ] **+ Add Playlist → From URL**: a valid M3U URL imports channels. An invalid URL shows an error and doesn't crash.
- [ ] **+ Add Playlist → From Files**: an `.m3u`/`.m3u8` file from Files imports. The success message shows the channel count.
- [ ] **QR Code**: opens scanner (or manual input in simulator), imports playlist from QR URL.
- [ ] **Media Server (Jellyfin / Emby)**: connect sheet accepts address and credentials, lists libraries and items.
- [ ] The heart on a channel adds it to Favorites, and the ♥ toolbar sheet lists it. Deleting a playlist removes its channels.
- [ ] **Local Videos** opens the Photos picker. A picked video imports and plays.
- [ ] **Mirror iPhone → CarPlay / Car Display**:
  - [ ] Opens Screen Mirroring sheet with ReplayKit Broadcast Picker.
  - [ ] Starting broadcast initiates low-latency H.264 HLS encoding (`MirrorHLSEncoder`) served at `http://127.0.0.1:8088/hls/live.m3u8`.
  - [ ] Inline player or CarPlay external screen plays live mirror stream with low latency.
  - [ ] Stopping broadcast cleanly shuts down HTTP server and segment store.
- [ ] **Browser** opens the browser. A site loads, back and forward work, and **Send to Car** hands off media to player; **Exit** closes browser.
- [ ] The **?** toolbar button opens "Car Display Setup". The **PRO** badge opens the paywall (if not unlocked).
- [ ] AirPlay to an Apple TV or AirPlay display: video shows on the external screen. Disconnecting returns to the phone.
- [ ] Wired or AirPlay external display: the external display view appears (`ExternalDisplayManager`).

## 2. Drive tab
- [ ] The tab opens with the "Drive" title and live map with vehicle telemetry HUD.
- [ ] Fresh install: Live map requests Location (*When In Use*) and Motion permissions.
- [ ] Speed gauge and G-force meters update smoothly while moving.
- [ ] Ending trip displays **Trip Summary** with route trace, smoothness score, and mileage stats.
- [ ] **Trip History & Replay** lists recorded trips and allows path replay via `TripReplayMapView`.
- [ ] Background automatic trip detection (CoreMotion + speed) detects drives and auto-records without manual trigger.
- [ ] Denying location shows a helpful recovery state, not a blank screen or a crash.

## 3. Widgets tab
- [ ] The tab opens with the "Widgets" title. The widget grid renders.
- [ ] Opening a widget shows "Edit widget". Changes save and persist after a relaunch.
- [ ] The video trimmer (if used) trims and previews correctly.
- [ ] The CarPlay dashboard mockup renders the chosen widgets.

## 4. Sounds tab
- [ ] The tab opens with the "Sounds" title. The sound catalog lists items.
- [ ] Tapping a sound plays it. Stop works. The sound plays over the silent switch and alongside other audio as designed.
- [ ] "Automations Guide" (Shortcuts) opens and is readable.

## 5. Me tab
- [ ] The tab opens with the "DashCast" title. Profile stats and trip metrics render.
- [ ] **Settings**, **About**, **Legal (Privacy / Terms / Support)**, and **Feedback** each open and close cleanly.
- [ ] Rate / Share actions present the system UI.
- [ ] Usage Metrics opens.
- [ ] The paywall shows the one-time $19.99 lifetime product (`pro.lifetime`). A sandbox purchase unlocks PRO, and **Restore Purchases** restores entitlements across reinstalls.

## 6. CarPlay
Needs the CarPlay entitlement on the build (see `testflight.md` and `Docs/CarPlay.md`).
*(Note: The old in-app CarPlay emulator was intentionally removed per decision D10 / PR #34; test in CarPlay Simulator or on head unit).*

### 6a. CarPlay Simulator (Mac, Xcode Additional Tools → CarPlay Simulator or Simulator → I/O → External Displays → CarPlay)
1. Connect the iPhone to the Mac over USB and launch **CarPlay Simulator**.
2. Unlock the iPhone and accept "Use CarPlay with this car".
- [ ] The DashCast icon appears on the CarPlay home screen grid.
- [ ] Launching it shows the CarPlay template UI (`CarPlaySceneDelegate`) with no crash on the phone.
- [ ] Navigating Library / Favorites / Info tabs works.
- [ ] Selecting a channel starts playback via `CarPlayNowPlayingController`.
- [ ] Favoriting on the phone updates CarPlay Favorites reactively.
- [ ] Template depth limits (≤ 5) respected without crash.
- [ ] Disconnecting and reconnecting CarPlay does not crash the app.

### 6b. Real head unit (if available)
- [ ] Wired CarPlay: app launch, playback and the dashboard all work. Audio routes to car speakers.
- [ ] Wireless CarPlay: same checks.
- [ ] CarPlay Video Mirroring: low-latency screen mirror displays on vehicle screen when parked.

## 6c. Drive: live map and automatic trips (Simulator & Device)
- [ ] Fresh install: Drive tab shows the "Show where you are" permission prompt. Tap **Allow Location** → *Allow While Using App*.
- [ ] Simulator menu **Features › Location › Apple** (or any custom location): the map centres on the blue dot, not the whole region. Pan away → **Recenter** appears and brings you back.
- [ ] Automatic trip detection prompt: tap **Allow All the Time** → *Change to Always Allow*. Status displays "Watching for drives".
- [ ] **Features › Location › Freeway Drive** (~100 km/h): status transitions to "Recording a drive". The recording HUD appears and follows heading.
- [ ] Switch to **Features › Location › None** (stopped): after ~3 min the trip is automatically saved and appears in Trip History.
- [ ] Real device: lock phone, drive ≥ 2 km, park ≥ 3 min → trip saved and notification received.

## 7. Regression & stability
- [ ] Switching quickly between all 5 tabs ×10 causes no crash or frozen UI.
- [ ] Low Power Mode and airplane mode: the app degrades gracefully (streams show errors, no hang).
- [ ] No crashes reported in TestFlight → Crashes for this build.
- [ ] Battery drain stays reasonable during a 30-min playback session (no runaway CPU or leak).

**Result:** ☐ Ship to testers ☐ Blocked (bugs: ______)
