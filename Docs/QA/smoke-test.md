# Manual smoke test (on device)

Run this checklist on a physical iPhone with every TestFlight build before handing it to
testers. CI already covers launch, tab switching, the Media Sources sheet and the Browser
sheet in the simulator (`DashCastUITests`, with screenshots in the `ui-test-screenshots` artifact).
This list covers what the simulator can't: real playback, AirPlay, permissions, sensors and CarPlay.

**Build:** ______ **Device / iOS:** ______ **Tester:** ______ **Date:** ______

Mark each item ✅ pass, ❌ fail (file a bug with a screenshot), or ⏭ not tested.

## 0. Install & launch
- [ ] The TestFlight build installs and the icon and name read "DashCast".
- [ ] A cold launch lands on the **Cast** tab in under 3 s with no crash.
- [ ] The app stays in dark mode. The tab bar shows Cast, Drive, Widgets, Sounds and Me.
- [ ] Turning to landscape and back keeps the layout intact.
- [ ] Background the app, then reopen it after 1 min. The state is preserved.

## 1. Cast tab
- [ ] **Media Source** opens the "Media Sources" sheet, which lists sample channels.
- [ ] Tapping a sample channel closes the sheet and starts playback in the inline player.
- [ ] Fullscreen toggle, pause/play and scrubbing work. Audio plays with the silent switch on (audio session).
- [ ] **+ Add Playlist → From URL**: a valid M3U URL imports channels. An invalid URL shows an error and doesn't crash.
- [ ] **+ Add Playlist → From Files**: an `.m3u`/`.m3u8` file from Files imports. The success message shows the channel count.
- [ ] The heart on a channel adds it to Favorites, and the ♥ toolbar sheet lists it. Deleting a playlist removes its channels.
- [ ] **Local Videos** opens the Photos picker. A picked video imports and plays.
- [ ] **Mirror iPhone** opens the Screen Mirroring sheet. The broadcast picker and AirPlay buttons respond.
- [ ] **Browser** opens the browser. A site loads, back and forward work, and **Exit** closes the browser.
- [ ] The **?** toolbar button opens "Car Display Setup". The **PRO** badge opens the paywall (if not unlocked).
- [ ] AirPlay to an Apple TV or AirPlay display: video shows on the external screen. Disconnecting returns to the phone.
- [ ] Wired or AirPlay external display: the external display view appears (ExternalDisplayManager).

## 2. Drive tab
- [ ] The tab opens with the "Drive" title and no crash.
- [ ] Starting a trip prompts for Location (When In Use) and then Motion permission. The prompt text is correct.
- [ ] While driving or walking, the speed gauge updates and the trip records. Ending it shows **Trip Summary** with a route and score.
- [ ] **Trip History** lists the trip. Drive settings open, and vehicle selection persists after a relaunch.
- [ ] Denying location shows a helpful state, not a blank screen or a crash.
- [ ] Notifications toggle: the permission prompt appears and a test notification arrives (if offered).

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
- [ ] The tab opens with the "DashCast" title. The stats and territory summary render.
- [ ] **Settings**, **About** and **Feedback** each open and close.
- [ ] Rate / Share actions present the system UI.
- [ ] Usage Metrics opens.
- [ ] The paywall shows the StoreKit price. A sandbox purchase unlocks PRO, and **Restore** works on a second install.

## 6. CarPlay
Needs the CarPlay entitlement on the build (see `testflight.md`). Without it, only the in-app
emulator applies.

### 6a. In-app CarPlay emulator (any build)
- [ ] Cast tab → CarPlay status section → open the emulator ("CarPlay Emulator" sheet). It renders and can be dismissed.

### 6b. CarPlay Simulator (Mac, Xcode Additional Tools → CarPlay Simulator)
1. Connect the iPhone to the Mac over USB and launch **CarPlay Simulator**.
2. Unlock the iPhone and accept "Use CarPlay with this car".
- [ ] The DashCast icon appears on the CarPlay home screen.
- [ ] Launching it shows the CarPlay template UI (CarPlaySceneDelegate) with no crash on the phone.
- [ ] Navigating the CarPlay lists and templates works. Back navigation works.
- [ ] Playback started from CarPlay plays audio and video. The phone UI stays in sync.
- [ ] The dashboard scene (CarPlayDashboardSceneDelegate) appears in the CarPlay Dashboard view.
- [ ] Disconnecting and reconnecting (unplugging USB) doesn't crash the phone app.
- [ ] Repeat with the phone locked.

### 6c. Real head unit (if available)
- [ ] Wired CarPlay: app launch, playback and the dashboard all work. Audio routes to the car speakers.
- [ ] Wireless CarPlay: same checks.

## 7. Regression & stability
- [ ] Switching quickly between all 5 tabs ×10 causes no crash or frozen UI.
- [ ] Low Power Mode and airplane mode: the app degrades gracefully (streams show errors, no hang).
- [ ] No crashes reported in TestFlight → Crashes for this build.

**Result:** ☐ Ship to testers ☐ Blocked (bugs: ______)
