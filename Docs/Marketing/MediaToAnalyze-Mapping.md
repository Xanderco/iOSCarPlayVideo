# DashCast — MediaToAnalyze Asset Catalog & Task Correlation Map [DI-13]

## Executive Summary
This document provides a comprehensive mapping of all 32 media reference assets stored in `MediaToAnalyze/` to their corresponding app screens, features, tasks, and implementation status for the **CarDash 1:1 Pixel Match (Electric Racing Yellow Theme)** redesign.

---

## 1. Asset-to-Screen Correlation Matrix

| Asset Filename | Primary Screen | Target Feature & UI Components | Correlated Task | Status |
|:---|:---|:---|:---|:---|
| `This should be the cast manu.jpeg` | **Cast** | 4-row menu card (`Media Source`, `Local Videos`, `Mirror iPhone`, `Browser`), hardware CarPlay illustration, status text, connection help link, AirPlay button | **DI-7** | Implemented (1:1 Yellow Theme) |
| `These are different sources that must be preadded for the user to easily cast from these .jpeg` | **Cast / Browser** | 20 preadded video sources grid (TikTok, YouTube, Netflix, Disney+, etc.), URL bar, bottom browser toolbar (`<`, `>`, `⌂`, `🔖`, `Send to car`) | **DI-7** | Implemented |
| `Connectio nHelp.jpeg` | **Cast / Help** | 4-step modal guide: 1. Connect to CarPlay, 2. Open DashCast, 3. Mirror iPhone, 4. Choose video | **DI-7** | Implemented |
| `Select Media Sources to show in Carplay App when connected to car.jpeg` | **Cast / CarPlay** | Media source picker for external CarPlay display playback | **DI-7** | Implemented |
| `Local video chooser.jpeg` | **Cast / Local** | PhotosUI video picker & Files importer drawer | **DI-7** | Implemented |
| `Only the App will show up when sharing screen.jpeg` | **Cast / Mirroring** | System broadcast picker sheet (`RPSystemBroadcastPickerView`) | **DI-7** | Implemented |
| `Enable the tracking always.jpeg` | **Drive / Perms** | Drive permission sheet: Location (Always Allow), Motion & Fitness, Notifications, with green badges | **DI-8** | Implemented / Mapped |
| `Live Activity when Open and in Carplay.jpeg` | **Drive / Live Activity**| Lock screen Live Activity widget with active car status | **DI-8** | Mapped |
| `Sending Messsages thought the day to test functionalities and when a drive is in progress and finished.jpeg` | **Drive / Push** | Drive push notifications ("Recording your drive", "Trip saved with peak G") | **DI-8** | Mapped |
| `Widgets available.jpeg` | **Widgets** | Category carousels: Plate, Couple Days, Date & Time, Countdown | **DI-9** | Implemented (1:1 Yellow Theme) |
| `Widgets Available 2.jpeg` | **Widgets** | Category carousels: Vinyl Record, Daily Quote, Christianity | **DI-9** | Implemented (1:1 Yellow Theme) |
| `All types of widgets.jpeg` | **Widgets** | Comprehensive widget showcase and grid variations | **DI-9** | Implemented |
| `How to showcase widgets and menu to create them.jpeg` | **Widgets** | Top CarPlay dashboard preview, "How to add to CarPlay?", My Widgets horizontal shelf | **DI-9** | Implemented |
| `Edit widgets on the same app.jpeg` | **Widgets / Editor** | Live editor with Size, Vertical, Horizontal sliders, Logo/Car toggle, sticker positioner | **DI-9** | Implemented |
| `edit widgets on the app.jpeg` | **Widgets / Editor** | Widget color and typography customization controls | **DI-9** | Implemented |
| `Costumize Widgets with Plate and Car Picture.jpeg` | **Widgets / Plate** | License plate editor with custom plate text and vehicle render overlay | **DI-9** | Implemented |
| `Car and Car Barnd Logo.jpeg` | **Widgets / Brands** | 100+ car brand logo catalog grid with brand filtering | **DI-9** | Implemented |
| `Sound Pickers.jpeg` | **Sounds** | Disconnection sound trigger, Home arrival trigger, Top trending 2-column soundboard with gradient cards, sticky "How to Activate? 🪄" CTA | **DI-10** | Implemented (1:1 Yellow Theme) |
| `Select CarPlay Connection Sound.jpeg` | **Sounds / Picker** | Sound picker sheet with category filter pills (`Recommend`, `All`, `Brands`, `Voices`, `Engine`), preview button, selection checkbox | **DI-10** | Implemented |
| `These stats and picture of the car.jpeg` | **Me / Profile** | Profile card with circular car artwork, `ROAD ROOKIE` rank badge, 3-column stats (`km driven`, `drives`, `badges`), PRO gold card, navigation list | **DI-11** | Implemented (1:1 Yellow Theme) |
| `Main Settings.jpeg` | **Me / Profile** | Primary account and garage overview layout | **DI-11** | Implemented |
| `SETTINGS.jpeg` | **Me / Settings** | Settings sheet: Lock Screen toggle, Speed units, Language, Restore purchase, Delete account | **DI-11** | Implemented |
| `About Screen.jpeg` | **Me / About** | About modal: AppIcon, version string, Privacy Policy, Terms of Use, Payment Agreement | **DI-11** | Implemented |
| `Feedback.jpeg` | **Me / Feedback** | Feedback sheet: "Tell us what's wrong", multiline text editor (min 10 chars), contact info, screenshot uploader (0/9), Send Feedback CTA | **DI-11** | Implemented |
| `How it should show up in the CarPlay.jpeg` | **CarPlay External** | CarPlay external display head-unit interface | **DI-7 / DI-12** | Implemented |
| `How the Carplay app launched from Carplay looks.jpeg` | **CarPlay External** | Active video player interface on vehicle dashboard screen | **DI-7 / DI-12** | Implemented |
| `Look how it explains the user in the carplay dashboard of my car.jpeg` | **CarPlay External** | In-car display guidance screen for external scenes | **DI-7 / DI-12** | Implemented |
| `competition video of how the functionality should look and also create a similar video for promotion.mp4` | **Marketing / Promo** | 92.5s competitor viral TikTok video (`@cartv_cast2car`). Deconstructed below. | **DI-13** | Deconstructed & Storyboarded |

---

## 2. Deconstruction of Competitor Promotional Video

### Video Specs
- **Source**: `MediaToAnalyze/competition video of how the functionality should look and also create a similar video for promotion.mp4`
- **Duration**: 92.51 seconds (1:32)
- **Format**: 1206 x 2622 (9:16 vertical video optimized for TikTok / Instagram Reels / YouTube Shorts)
- **Creator Account**: `@cartv_cast2car` (31.1K followers, 2.3M likes, videos reaching 3.8M - 6.2M views)
- **Vehicle Used**: BMW 3-Series / 4-Series modern curved cockpit display (running wireless Apple CarPlay)

### Structural Breakdown & Pacing:
1. **The Instant Hook (0:00 - 0:08)**:
   - *Visual*: Host sitting in the driver's seat of a modern car parked in a garage at night with ambient cockpit lighting.
   - *Speech/Subtitle*: *"Si tu carro tiene CarPlay..."* ("If your car has CarPlay... you need to know this").
   - *Psychology*: Direct address to car owners. Triggers curiosity and addresses a universal driver desire: watching video on the car screen during charging or breaks.

2. **The Problem / Frustration (0:08 - 0:22)**:
   - *Visual*: Showing that Apple CarPlay natively disables video streaming apps like YouTube or Netflix.
   - *Voiceover*: Explaining how people buy expensive hardware dongles ($100–$200 Android AI boxes) that are laggy, overheat, or require dangerous jailbreaking.

3. **The Solution & Live Demonstration (0:22 - 0:55)**:
   - *Visual*: Host holds up their iPhone. Taps the app, selects "Browser" or "Cast", taps YouTube / soccer match / movie stream.
   - *Magic Moment*: Cuts to the wide car cockpit display instantly projecting smooth 1080p full-screen video with audio coming through the car's premium sound system.
   - *Feature Walkthrough*: Demonstrates full-screen playback, audio controls on steering wheel, and how easy it is to search for any video.

4. **Addressing Safety & Legality (0:55 - 1:05)**:
   - *Notice*: Clear on-screen text and voiceover explaining: *"Para usar mientras esperas, cargas el coche o descansas"* (For use while parked, charging your EV, or waiting). Builds trust with viewers and complies with App Store / TikTok safety guidelines.

5. **Competitor Weakness & The DashCast Disruption (1:05 - 1:20)**:
   - *Competitor Flaw*: Competitors charge recurring subscriptions ($9.99/mo or $4.99/mo), which users hate and cancel after a few weeks.
   - *Our Core Disruption*: **Pay Once ($19.99 Lifetime). Own Forever. Zero Subscriptions.**

6. **Call To Action (1:20 - 1:32)**:
   - *Visual*: App icon, App Store search animation, and bio link pointer.
   - *Action*: *"Descárgalo hoy en la App Store — link en la bio."*
