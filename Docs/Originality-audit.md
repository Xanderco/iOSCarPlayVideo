# Originality audit (App Review 4.1 / 5.2)

Date: 2026-11-05 · Session: redesign 2B (`claude/redesign-secondary`) · Base: `d64237c`

**Why:** DashCast began as a deliberate "1:1" copy of the App Store app **CarDash** ("Drive Tracker, Scores &
Sounds", tabs Cast / Drive / Widgets / Sounds / Me). App Review rejects copycats (guideline **4.1**) and anything
using third-party IP without rights (**5.2**). DashCast has to stand on its own as a **video player for the car
display** (Journal D2). This document lists what was competitor-derived, what this PR changed, and what other
owners still have to fix.

Legend: ✅ fixed in this PR · ➡️ owned by another session/PR (listed so it isn't lost) · ⚠️ owner decision / human to-do

---

## 1. Summary

| Area | Finding | Status |
|---|---|---|
| Information architecture | 5 tabs copied 1:1 (Cast/Drive/Widgets/Sounds/Me, comment "Matches CarDash exact 5 native tabs") | ✅ Home · Library · Cast · Drive · Settings (Widgets/Sounds/Me gone as tabs) |
| Drive / Widgets / Sounds | CarDash's core features, screens rebuilt from its screenshots | ✅ Widgets + Sounds redesigned as **Car Extras** in Settings · ➡️ Drive kept as a feature, owned by the Drive session (§3) |
| "Me" profile | Copied 1:1 from CarDash ("ROAD ROOKIE" badge, km / drives / badges stats, PRO banner, menu order) | ✅ Replaced by native grouped **Settings** |
| User-facing strings | "CarDash is tracking this trip" (already fixed by #18), CarDash's sound names, "Chevrolet Trax" default from a CarDash screenshot | ✅ Rewritten (Drive: strings only) · ➡️ Drive's marketing "tip" notifications (§6) |
| Competitor screenshots in repo | 31 CarDash screenshots in `MediaToAnalyze/`; CarTV TikTok ad frames in `Screenshots/VideoFrames/` | ✅ Removed from the tree and git-ignored (§4) |
| Clone-era screenshots of our app | `Screenshots/*.png` (labelled "1to1", "Cast_Yellow", …) | ✅ Removed from the tree and git-ignored (§4) |
| Third-party car photos **in the app bundle** | 8 manufacturer-style renders (Porsche, BMW, Mercedes-AMG, Corvette, …), twice: asset catalog + `Resources/CarImages` | ✅ Removed from the bundle (§5) |
| Fake features | Sounds told users to add a "DashCast action" that didn't exist; Feedback showed "sent" without sending | ✅ Real Shortcuts action (`PlayCarChimeIntent`); Feedback opens Mail |
| Code comments | "1:1", "Exact 1:1 CarDash layout", "matching CarDash screenshot #6" | ✅ All gone from shipped code (2 comment-only edits in Cast files, Territory removed by #21) |
| Docs | PROGRESS/PAPERCLIP/README describe a "CarDash 1:1 Yellow redesign" | ✅ README · ⚠️ historical logs (§7) |
| App Store screenshots | `AppStoreMedia/` showed the clone's 5 tabs incl. Territory | ✅ Removed by #21 (only `metadata.md` + `reviewer-demo.m3u` remain); new screenshots must show the 4-tab app |
| Territory feature | Hex "territory" (CarDash-adjacent gamification) | ✅ Removed by #21 (Journal D3) |
| Bundled sample videos | `Resources/Videos/night_drive.mp4`, `track_lap.mp4`, provenance not recorded | ⚠️ Confirm licence or replace (§5) |

Verification: `git grep -niE "cardash|cartv|1:1|1to1" -- DashCast DashCastTests DashCastUITests project.yml`
matches only binary bytes inside the two sample `.mp4` files (no text hits).

---

## 2. What makes DashCast different now

- **Product:** a player for the passenger's *own* video (playlists, links, files, servers) on iPhone and the car
  display. No trip scoring, no badges, no car-personality widgets as headline features.
- **IA:** Home · Library · Cast · Drive · Settings. Car Extras (Car Screen, Car Chime) live one level down in Settings.
- **Look:** DashCast design system v2 (Signal Green on OLED black, native lists/sheets, SF Symbols). No yellow
  racing theme, no capsule tab bar, no competitor colours.
- **Copy:** all strings in Settings, Extras and onboarding were written fresh for this PR.
- **Safety:** first-run onboarding with a passenger-only notice that has to be acknowledged; the notice is
  also in Settings › Car › Passenger safety.
- **Privacy:** no account, no analytics SDKs, on-device data; in-app privacy summary + links.

---

## 3. Decision: Drive, Widgets and Sounds (Journal O2), resolved

**Owner decision (2026-11-05): Drive stays as a real feature; Widgets and Sounds go under Extras.**

| Was (CarDash-derived) | Now | Notes |
|---|---|---|
| **Drive** tab | **Drive tab, kept** (Home · Library · Cast · Drive · Settings) | Owned by the Drive session (`Features/Drive/*`). This PR only placed it in navigation and fixed strings (a "1:1" comment, the "Chevrolet Trax" default). `DriveHomeView` is a tab-root screen with its own `NavigationStack`, so it stays a tab rather than a pushed Settings screen. To stay clear of 4.1, Drive needs its *own* take (see §6), not CarDash's score/badge/garage loop. |
| **Widgets** tab: car brand/model catalogue with stock car photos, licence plate, stickers, countdowns, CarPlay dashboard mock-up, video trimmer | **Settings › Car Extras › Car Screen**: three short lines of text for the car display between videos (live 16:9 preview), plus the user's *own* car photo and optional plate for the Home Screen widget (`claude/home-widgets`) | Removed: dashboard mock-up, trimmer, stickers/countdown UI. `WidgetConfigModel` unchanged. `VehicleCatalogService` stays only because Drive's settings use it |
| **Sounds** tab: CarDash's sound list ("Jet Startup", "Welcome Back Sir", "Sport Car Startup - 1", …), 3 slots, trending cards, a Shortcuts guide for an action that didn't exist | **Settings › Car Extras › Car Chime**: 13 chimes with new names, synthesized on device; one slot; a real **"Play Car Chime"** Shortcuts action (`PlayCarChimeIntent`) | Old sound ids in saved preferences fall back to the default chime |

Deep links: `-initialTab drive` → Drive tab; `widgets` / `sounds` → Settings › Car Extras; `me` → Settings.

## 4. Reference media removed from the repository

Removed from the working tree in this PR and added to `.gitignore`. They are **not** in the app bundle (the
`DashCast` target only compiles `DashCast/`), but they shouldn't sit in the product repo either. They stay in git
history; to look at one locally: `git show d64237c:"<path>" > /tmp/file`. Keep any local copies in the
git-ignored `ReferenceMedia/` folder.

### 4.1 Competitor screenshots: `MediaToAnalyze/` (31 files, CarDash)

- `MediaToAnalyze/About Screen.jpeg`
- `MediaToAnalyze/All types of widgets.jpeg`
- `MediaToAnalyze/Car and Car Barnd Logo.jpeg`
- `MediaToAnalyze/Connectio nHelp.jpeg`
- `MediaToAnalyze/Costumize Widgets with Plate and Car Picture.jpeg`
- `MediaToAnalyze/Edit widgets on the same app.jpeg`
- `MediaToAnalyze/Enable the tracking always.jpeg`
- `MediaToAnalyze/Feedback.jpeg`
- `MediaToAnalyze/Have all this info and allow them to select and customize.jpeg`
- `MediaToAnalyze/How it should show up in the CarPlay.jpeg`
- `MediaToAnalyze/How the Carplay app launched from Carplay looks.jpeg`
- `MediaToAnalyze/How to showcase widgets and menu to create them.jpeg`
- `MediaToAnalyze/Live Activity when Open and in Carplay.jpeg`
- `MediaToAnalyze/Local video chooser.jpeg`
- `MediaToAnalyze/Look how it explains the user in the carplay dashboard of my car.jpeg`
- `MediaToAnalyze/Main Settings.jpeg`
- `MediaToAnalyze/Only the App will show up when sharing screen.jpeg`
- `MediaToAnalyze/SETTINGS.jpeg`
- `MediaToAnalyze/Select CarPlay Connection Sound.jpeg`
- `MediaToAnalyze/Select Media Sources to show in Carplay App when connected to car.jpeg`
- `MediaToAnalyze/Sending Messsages thought the day to test functionalities and when a drive is in progress and finished.jpeg`
- `MediaToAnalyze/Sound Pickers.jpeg`
- `MediaToAnalyze/These are different sources that must be preadded for the user to easily cast from these .jpeg`
- `MediaToAnalyze/These stats and picture of the car.jpeg`
- `MediaToAnalyze/This is how it should look like the other app on my carplay apps menu but its not showing up.jpeg`
- `MediaToAnalyze/This is how its looking right now im not able to select to cast the screen like the other app i can.jpeg`
- `MediaToAnalyze/This should be the cast manu.jpeg`
- `MediaToAnalyze/Widgets Available 2.jpeg`
- `MediaToAnalyze/Widgets available.jpeg`
- `MediaToAnalyze/edit widgets on the app.jpeg`
- `MediaToAnalyze/mroe widgets.jpeg`

### 4.2 Competitor ad frames: `Screenshots/VideoFrames/` (CarTV TikTok ad)

- `Screenshots/VideoFrames/frame_05s.png`
- `Screenshots/VideoFrames/frame_20s.png`
- `Screenshots/VideoFrames/frame_40s.png`
- `Screenshots/VideoFrames/frame_60s.png`
- `Screenshots/VideoFrames/frame_80s.png`

### 4.3 Screenshots of the clone-era UI: `Screenshots/` (21 files)

- `Screenshots/01_Initial_Launch.png`
- `Screenshots/02_Running.png`
- `Screenshots/03_Ready.png`
- `Screenshots/04_Screen_Me.png`
- `Screenshots/05_Screen_Cast_Yellow.png`
- `Screenshots/06_Screen_Cast_1to1.png`
- `Screenshots/07_Screen_Cast_Polished.png`
- `Screenshots/08_Screen_Drive_Initial.png`
- `Screenshots/09_Screen_Drive_Polished.png`
- `Screenshots/10_Screen_Widgets_Initial.png`
- `Screenshots/11_Screen_Widgets_Polished.png`
- `Screenshots/12_Screen_Sounds_Polished.png`
- `Screenshots/13_Screen_Me_1to1.png`
- `Screenshots/14_Screen_Paywall.png`
- `Screenshots/15_Liquid_Capsule_TabBar_DI6.png`
- `Screenshots/16_Drive_HUD_DI8.png`
- `Screenshots/17_Widget_Editor_DI9.png`
- `Screenshots/18_iPhone_Screen.png`
- `Screenshots/19_CarPlay_Emulator_Launched.png`
- `Screenshots/20_CarPlay_Dashboard_Mode.png`
- `Screenshots/21_CarPlay_Home_Menu_Mode.png`

### 4.4 `AppStoreMedia/`

The clone-era screenshots were already removed by #21. New screenshots must be captured from the 4-tab app.

### 4.5 Docs that describe the reference media

`Docs/Marketing/MediaToAnalyze-Mapping.md` and `Docs/Marketing/Competitor-Analysis.md` are internal competitive
research. Studying competitors is fine; what matters is that nothing from them ships. They now point at images
that are no longer in the tree.

---

## 5. App bundle contents (what actually ships)

| Asset | Finding | Status |
|---|---|---|
| `Assets.xcassets/car_*.imageset` (8) | Manufacturer-style press renders of real models (e.g. file `car_porsche_911` is actually a Porsche 718 Boxster). Third-party copyright + trademarks, and the "pick your car" feature is CarDash's | ✅ Deleted |
| `Resources/CarImages/*.png` (8) | Loose duplicates of the above, also bundled | ✅ Deleted |
| `AppIcon` | Speedometer dial + play screen. Original artwork, but the speedometer says "drive tracker" | ➡️ Icon session (Journal: "Territory removal + icon") |
| `Resources/Videos/night_drive.mp4`, `track_lap.mp4` | Sample videos used by `IPTVParser`'s built-in sample playlist; source and licence not recorded | ⚠️ Owner: confirm we made/own them, or replace with self-made clips (Journal D5) |
| `DashCastStore.storekit` | StoreKit test config | OK |

Fallback: `WidgetConfigModel`'s default values and the fallbacks in `CarPlayExternalDisplayView` /
`CarPlaySimulatorView` still say `"Porsche" / "911 GT3 RS" / "car_porsche_911"`. This PR makes them unreachable in
practice: the app seeds a neutral Car Screen config on first launch (`CarScreenDefaults.seedIfNeeded`), and the
image falls back to an SF Symbol now that the renders are gone. ➡️ Model owner (WidgetKit session) / Cast owner:
change those defaults to neutral text and drop the `realCarImageView` slot.

---

## 6. Leftovers for other owners ➡️

| File | What | Owner |
|---|---|---|
| `Core/Models/WidgetConfigModel.swift`, `Features/Cast/CarPlayExternalDisplayView.swift`, `Features/Cast/CarPlaySimulatorView.swift` | `Porsche / 911 GT3 RS / car_porsche_911` defaults (see §5) | WidgetKit session / Cast |
| `Features/Drive/*` | Shows a driving **score**, a "garage" vehicle picker with brand catalogue, and schedules marketing "tip" notifications ("Make your CarPlay screen yours in 30 seconds"). These mirror CarDash's Drive loop. The vehicle picker now shows no photos because the stock renders were removed (§5) | Drive session |
| `Features/Drive/DriveTrackingPermissionsSheet.swift` | `Image("car_porsche_911")` (asset removed, now renders nothing) | Drive session |
| `Features/Pro/LifetimePaywallView.swift` | Check the feature list still matches the app (no Drive scores / sounds-as-headline) | Paywall session |
| `DashCastWidgets/TripStatsWidget.swift` (`claude/home-widgets`) | Shows the trip **score**; the app no longer shows scores. Recommend distance/time only | WidgetKit session |
| `Features/MediaServers/MediaServerViews.swift` | Hosted as the Library tab root for now; its "Done" button does nothing there | Redesign 2A (real Library) |
| `Features/Cast/CastHomeView.swift` | Hosted as the Home tab until 2A splits Home / Library / Cast & Mirror | Redesign 2A |

## 7. Docs and process

- ✅ `README.md`: removed the "premium capabilities of subscription-based apps like CarDash" positioning.
- ⚠️ `PROGRESS.md`, `PAPERCLIP.md`, `Docs/Paperclip/*`: historical agent logs ("CarDash 1:1 Pixel Match & Racing
  Yellow Redesign", "Company Name: CarDash / DashCast Inc."). Not shipped. Recommend archiving them under
  `Docs/Archive/` with a note that the direction was reversed by Journal D2. Left untouched here to avoid
  conflicts with the integrator's log edits.
- ⚠️ `.paperclip/agents/*`: agent prompts that instruct "1:1 parity" with competitors must be rewritten before
  any Paperclip agent is resumed, or they will re-introduce copied UI.
- ⚠️ Hosted pages: `https://dashcast.app/privacy` (used by the paywall and Settings) and `support@dashcast.app`
  must exist before submission. Terms of Use link to Apple's standard EULA.

## 8. Checklist before submission

- [ ] `git grep -niE "cardash|cartv|1:1"` over `DashCast/` returns nothing (after §6 owners land)
- [ ] No third-party logos, photos, streams or sounds in `DashCast/Resources` (confirm the two sample videos)
- [ ] App Store screenshots regenerated from the 4-tab app; none show Drive/Widgets/Sounds tabs or Territory
- [ ] Metadata says "car display", not "CarPlay" (Journal D6); no competitor names in keywords
- [ ] Privacy policy URL live; App Privacy answers: location (Drive, not linked to user, not used for tracking)
