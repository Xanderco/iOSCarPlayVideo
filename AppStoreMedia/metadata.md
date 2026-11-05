# DashCast: App Store Connect listing

Copy-ready metadata for App Store Connect. All copy is original. The positioning (utility video player that
plays the user's own M3U/IPTV playlists and media, with a car-display mode) follows the category
and structure that comparable player apps have used to pass review. No competitor text is reused.

Character limits are checked; counts are in brackets.

---

## 1. Identity

| Field | Value |
|---|---|
| **App name** (30) | `DashCast - M3U Player & Cast` [28] |
| Alternatives | `DashCast: IPTV Player & Cast` [28] · `DashCast - Video Player & Cast` [30] |
| **Subtitle** (30) | `Car-screen video. Pay once.` [27] |
| Alternative subtitles | `Pay once. No subscriptions.` [27] · `Your videos on the car screen` [29] |
| Bundle ID | `com.xanderco.dashcast` |
| SKU | `DASHCAST-IOS-001` |
| Primary category | **Utilities** |
| Secondary category | **Entertainment** |
| Devices | **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`) |
| Price | **Free download** with a limited free tier, plus **one** in-app purchase: **DashCast Pro** (lifetime, non-consumable, USD 19.99) |
| Account | **None.** No sign-up and no login. |

> ⚠️ Do **not** put the word "CarPlay" in the name, subtitle, keywords, promo text or screenshots
> unless Apple has granted the CarPlay entitlement for this bundle ID. Say "car display" or "car screen" instead.
> The description may say "works with compatible car displays and AirPlay/HDMI screens".

---

## 2. Pricing model: pay once, keep it forever

DashCast has **no subscriptions**. The download is free and includes a limited free tier. **One** in-app purchase unlocks everything for good.
This is our main point of difference: comparable car-video and IPTV player apps charge weekly or yearly.

| Field | Value |
|---|---|
| Product ID | `com.dashcast.lifetime` (already used by `StoreKitManager` and `DashCastStore.storekit`) |
| Type | **Non-Consumable** |
| Reference name | DashCast Pro Lifetime |
| Display name | **DashCast Pro** |
| Description (≤ 55) | `Unlock every DashCast feature for good. Pay once.` [49] |
| Price | **USD 19.99** (pick the 19.99 price point; App Store Connect sets other storefronts) |
| Family Sharing | Optional. The local StoreKit config has `familyShareable: true`. Turn it on in App Store Connect only if you want it, and only then mention it in the copy. |
| Review screenshot | `AppStoreMedia/6.9-inch_1320x2868_plain/02_paywall.png` |
| Review note | *"Single non-consumable purchase. It unlocks DashCast Pro permanently on this Apple ID. There is no subscription. Restore Purchases is on the paywall and in Me → Settings."* |

Don't use any wording about trials, renewal or billing periods anywhere: in the app, the listing, the IAP or the screenshots.

> ⚠️ **Free tier vs Pro must be implemented before submission.** Today `isProLifetimeUnlocked` only hides
> the "PRO" toolbar buttons and changes banner text. No feature is actually limited for free users, so
> the purchase unlocks nothing. Reviewers test this (Guidelines 2.1 and 3.1.1), and the listing must not
> describe limits that don't exist (2.3.1). Pick the split and implement it in the Cast, Widgets and Sounds tabs. A suggested split that the
> current features can support:
>
> | Free | DashCast Pro |
> |---|---|
> | 1 playlist, local videos, iPhone playback | Unlimited playlists and car/external-display output |
> | 2 widget designs | All car models, stickers and live wallpapers |
> | A few sounds | Full sound library and arrival/connection trigger sounds |
> | Drive stats and trip history | (same, drive stats stay free) |
>
> Once it is implemented, replace the bracketed list in §4 "FREE VS PRO" and in the reviewer notes with the real split.

## 3. Promotional text (170)

```
Pay once, keep it forever - no subscriptions. Play your own playlists, streams and videos on the car screen for passengers and parked breaks. No account, no tracking.
```
[166] (Promotional text can be changed at any time without a new build.)

---

## 4. Description

```
PAY ONCE, KEEP IT FOREVER - NO SUBSCRIPTIONS.
DashCast is free to download. One in-app purchase, DashCast Pro, unlocks everything for good. You pay one price, once. There's no weekly or yearly fee.

DashCast plays the videos you already own, and the playlists and streams you already have, on your iPhone and on a connected car display. It is made for passengers and for parked breaks such as EV charging stops.

DashCast ships with no channels or content. You add your own.

WHAT IT DOES
• Plays M3U and M3U8 playlists that you add from a URL or the Files app
• Plays HLS streams and video files that you import from Photos or Files
• Sends video to a connected external display: a car screen through a compatible adapter, AirPlay or HDMI. Your iPhone stays the remote.
• Mirrors your iPhone screen with the system screen-broadcast picker

SUPPORTED FORMATS
• Playlists: .m3u, .m3u8 (EXTINF titles, group-title and tvg-logo attributes)
• Streams: HLS (.m3u8) and HTTP(S) video
• Files: video formats that iOS can play, such as MP4, MOV and M4V (H.264 / HEVC)

YOUR OWN MEDIA SERVER
Add the playlist link that your home media server or NAS publishes, then watch your own library on the road. DashCast does not provide, host, sell or recommend any streams.

CAR MODE
A simple layout with large controls for the car screen. Video is for passengers, or for when you're parked. While the car is moving, use audio only.

PLAYLISTS
Add playlists from a link or a file, refresh them with one tap, remove the ones you don't need and mark favourite channels. Everything stays on your iPhone.

MORE THAN A PLAYER
• Drive stats: live speed, distance and duration, a smooth-driving score and a speed-coloured route map for every trip, with trip history
• Dashboard widgets and live wallpapers with your car model, a greeting, plates, countdowns and stickers
• A sound board with arrival and connection sounds, plus a step-by-step Shortcuts guide to play them automatically

FREE VS PRO
[Fill in after the free tier is implemented, e.g. "Free: 1 playlist, iPhone playback, drive stats. DashCast Pro: unlimited playlists, car-display output, every widget and sound."]

PRIVACY
No account. No ads. No tracking. No analytics. Your playlists, history and trips stay on your iPhone. Location is used on the device to show speed and trip stats and is never uploaded.

Privacy Policy: https://dashcast.app/privacy
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Support: https://dashcast.app/support

DISCLAIMER
DashCast is a media player only. It does not include or provide any TV channels, playlists or video content. You are responsible for having the rights to the content you add. DashCast is not affiliated with any broadcaster, streaming service or car maker.

SAFETY
For passengers only, or when the vehicle is parked. Never watch video while driving. Follow local laws about screens that the driver can see.
```

### Our differentiators (every one exists in the current build)

| Differentiator | Where in the app |
|---|---|
| **Pay once, keep it forever, no subscriptions** (one non-consumable, USD 19.99) | `LifetimePaywallView`, `StoreKitManager` |
| No account, no ads, no tracking, no analytics, data stays on the device | `PrivacyInfo.xcprivacy`, no network backend |
| Your own playlists (URL or Files), local video import, favourites | Cast tab → Media Sources / Local Videos / Favorites |
| External display and AirPlay output with the iPhone as remote, plus screen mirroring | `ExternalDisplayManager`, `AirPlayRoutePickerRepresentable`, `ScreenBroadcastPickerView` |
| Drive stats with a smooth-driving score, speed-coloured route map and trip history | Drive tab, `TripSummaryView`, `SpeedGradientRouteView` |
| Car dashboard widgets and live wallpapers (car models, plates, countdowns, stickers) | Widgets tab, `WidgetEditorView` |
| Arrival and connection sound board with a Shortcuts automation guide | Sounds tab, `ShortcutsGuideView` |
| Passenger-only safety notice built in | first launch, Me → Settings |

Don't claim anything that isn't in this table (for example Picture in Picture, playlist renaming or reordering, CarPlay, or any bundled channels) until it ships.

---

## 5. Keywords (100)

```
m3u,m3u8,iptv,player,video,stream,playlist,hls,car,screen,display,passenger,parked,media,server,tv
```
[98] No competitor names and no trademarks (no "CarPlay", YouTube, Netflix, Plex and so on). Words already in the name or subtitle don't need to be repeated, so swap in other words if the name changes.

---

## 6. URLs (placeholders, must be live before submission)

| Field | URL |
|---|---|
| Support URL | `https://dashcast.app/support` *(placeholder: needs a contact email or form)* |
| Marketing URL | `https://dashcast.app` *(optional)* |
| Privacy Policy URL | `https://dashcast.app/privacy` *(placeholder: needs a hosted page saying no data is collected)* |
| Terms of Use / EULA | Apple Standard EULA: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`. Keep the App Store Connect "License Agreement" set to Apple's standard EULA, or upload a custom one and update `LegalLinks.termsOfUse`. |

The same URLs are in the app (`DashCast/Core/Legal/LegalLinks.swift`): Me → Settings → Legal, Me → About and the paywall footer.

---

## 7. Age rating questionnaire

Based on Apple's updated age-rating questions (2025+). Answer honestly:

| Question | Answer |
|---|---|
| Parental controls / age assurance | No |
| Unrestricted Web Access | **Yes**, while the in-app web video browser (`WebVideoBrowserView`) exists |
| User-generated content / messaging / chat | No |
| Advertising | No |
| Gambling, simulated gambling, contests | None |
| Violence (cartoon / realistic / prolonged) | None |
| Sexual content, nudity | None |
| Profanity / crude humour | None |
| Alcohol, tobacco, drugs | None |
| Horror / fear themes | None |
| Mature / suggestive themes | None |
| Medical / treatment information | None |
| Health or wellness topics | No |
| Loot boxes | No |

**Expected rating:** **18+** because of Unrestricted Web Access.
**Trade-off for the owner:** if the in-app web browser is removed (or limited to a fixed allow-list of
sites), answer "No" to Unrestricted Web Access and the app should get **4+**. That makes it
more discoverable, but it drops the "watch websites on the car screen" feature. See `Docs/AppReview-checklist.md` → Age rating.

---

## 8. App Privacy ("nutrition label")

**Data collection:** *"No, we do not collect data from this app."* → the label shows **Data Not Collected**.

Why this is accurate:
- No account, analytics, crash-reporting SDK, ads or tracking. `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false` and no collected data types.
- Location (speed and trip stats) is processed and stored **on-device only** and is never transmitted, so under Apple's definition it is not "collected".
- Playlists, history, widgets and trips are stored in the app's UserDefaults or container on the device.
- Purchases go through **StoreKit only**. Apple processes the payment and the developer receives no personal data.
- Playlist and stream URLs entered by the user are fetched directly from the user's own server. DashCast operates no server.

Required-reason APIs (in `DashCast/Resources/PrivacyInfo.xcprivacy`): UserDefaults `CA92.1` and File timestamp `C617.1`.

Export compliance: `ITSAppUsesNonExemptEncryption = NO` (HTTPS only, exempt).

---

## 9. App Review information

**Sign-in required:** No (the app has no accounts).
**Contact:** owner name, phone and email *(fill in)*.

**Notes for the reviewer** (paste into "Notes"). Fill in the bracketed free/Pro split first:

```
Thank you for reviewing DashCast.

WHAT THE APP IS
DashCast is a video player. It ships with NO channels, playlists or third-party content and does not provide, host or sell any streams. Users add their own M3U/M3U8 playlists, media-server links or video files from Photos/Files.

PRICING
Free download with a limited free tier. A single non-consumable in-app purchase, "DashCast Pro" (USD 19.99), unlocks everything permanently. There are no subscriptions. Pro unlocks: [list the Pro-only features once implemented].

HOW TO TEST (about 2 minutes)
1. Launch the app and read the passenger-safety notice, then tap "I Understand".
2. On the Cast tab, open "Media Sources", tap "+ Add Playlist" → "From URL" and paste this demo playlist:
   https://dashcast.app/demo/reviewer.m3u
   It lists two open-licence (Creative Commons) Blender Foundation films that we host for review.
3. Tap a channel to play it. Use the AirPlay or screen button to send video to an external display.
4. Optional: Cast → Import → choose any video from Photos.
5. Me → Settings shows Restore Purchases, Privacy Policy, Terms of Use (EULA) and Support.
6. The paywall (Me → "Upgrade Now", or the "PRO" button) shows the one-time USD 19.99 price for DashCast Pro and a Restore button. You can buy it with a Sandbox account. Restore Purchases is also in Me → Settings.

HOW THE CAR DISPLAY WORKS
DashCast uses the standard iOS external-display APIs (UIScreen / scene sessions and AVPlayer external playback via AirPlay). When a screen is connected through a compatible adapter, AirPlay receiver or HDMI, the player shows video on that screen and the iPhone becomes the remote. Without an external screen, video plays on the iPhone.

SAFETY
Video is for passengers only, or for use while the vehicle is parked. This is shown on first launch, in Settings and in car mode. While driving, only audio is intended.

PRIVACY
No account, no analytics, no ads and no tracking. Location is used on-device only for the speed and trip screen.
```

> Before submission: host `AppStoreMedia/reviewer-demo.m3u` at the URL above (or change the URL in
> the notes) and check that it plays on a device. If the reviewer can't play anything, the app gets a
> Guideline 2.1 rejection.

---

## 10. Screenshots

Generated in CI by `.github/workflows/appstore-media.yml` → `Scripts/generate-appstore-media.sh` →
`Scripts/compose-appstore-frames.py`.

| Set | Size | Artifact |
|---|---|---|
| 6.9" (iPhone 17/16 Pro Max) framed | 1320 × 2868 | `appstore-screenshots-framed` → `6.9-inch_1320x2868/` |
| 6.5" framed | 1284 × 2778 | `appstore-screenshots-framed` → `6.5-inch_1284x2778/` |
| Plain (unframed) at exact sizes, plus raw captures | both | `appstore-screenshots-plain` |

Order: 01 Cast · **02 Paywall ("Pay once. Keep it forever." + "No subscriptions")** · 03 Car display · 04 Drive · 05 Widgets · 06 Sounds · 07 Me.
Every frame has the footer *"For passengers & parked use only. Never watch while driving."*

**Before uploading, check each screenshot** (Guidelines 2.3.3, 2.3.7, 5.2): no third-party logos (Netflix,
Disney+, YouTube…), no copyrighted footage, no "CarPlay" wording and only features that really work.
The Cast and Car-display screens show whatever sample channels the Cast module bundles. See the checklist.

---

## 11. What's New (first version)

```
Welcome to DashCast: your own playlists and videos on the car display, for passengers and parked breaks. Pay once, keep it forever, with no subscriptions.
```
