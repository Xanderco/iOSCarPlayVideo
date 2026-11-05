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
| **Subtitle** (30) | `Your videos on the car screen` [29] |
| Alternative subtitles | `Video for passengers & parking` [30] · `Play your lists on any screen` [29] |
| Bundle ID | `com.xanderco.dashcast` |
| SKU | `DASHCAST-IOS-001` |
| Primary category | **Utilities** |
| Secondary category | **Entertainment** |
| Devices | **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`) |
| Price | **Free**, with an In-App Purchase |
| Account | **None.** No sign-up and no login. |

> ⚠️ Do **not** put the word "CarPlay" in the name, subtitle, keywords, promo text or screenshots
> unless Apple has granted the CarPlay entitlement for this bundle ID. Say "car display" or "car screen" instead.
> The description may say "works with compatible car displays and AirPlay/HDMI screens".

---

## 2. In-App Purchases

Currently configured (`DashCast/Resources/DashCastStore.storekit`, `StoreKitManager`):

| Product ID | Type | Reference name | Price | Display name |
|---|---|---|---|---|
| `com.dashcast.lifetime` | Non-Consumable | DashCast Pro Lifetime | $19.99 (Tier 20) | DashCast Pro – Lifetime |

Optional (only if the owner adds them; they need code, the StoreKit config and paywall changes):

| Product ID | Type | Suggested price | Notes |
|---|---|---|---|
| `com.dashcast.pro.weekly` | Auto-renewable, group "DashCast Pro" | $2.99 / week | Paywall must show the price **and** the period. Add the 3.1.2 subscription disclosure text below. |
| `com.dashcast.pro.yearly` | Auto-renewable, same group | $24.99 / year | Same as above. Show the per-week equivalent only as secondary text. |

IAP review screenshot: the paywall (`AppStoreMedia/6.9-inch_1320x2868_plain/07_paywall.png`).

IAP review note: *"Unlocks unlimited playlists, car-display output, widgets and sounds. One-time purchase, no
account. Restore Purchases is in the paywall and in Me → Settings."*

---

## 3. Promotional text (170)

```
Turn the car screen into a cinema for your passengers. Play your own M3U playlists, media server streams and videos. One-time unlock, no account and no tracking.
```
[160]

---

## 4. Description

```
DashCast plays the videos you already own, and the playlists and streams you already have, on your iPhone and on a connected car display. It is made for passengers and for parked breaks such as EV charging stops.

DashCast ships with no channels or content. You add your own.

WHAT IT DOES
• Plays M3U and M3U8 playlists from a URL or a file, grouped by category
• Plays HLS streams and common video files (MP4, MOV, M4V) that you import from Photos or Files
• Sends video to a connected external display: a car screen through a compatible adapter, AirPlay or HDMI. Your iPhone stays the remote.
• Picture in Picture: keep a passenger's video playing in a mini player while you use other apps

SUPPORTED FORMATS
• Playlists: .m3u, .m3u8 (EXTINF titles, group-title and tvg-logo attributes)
• Streams: HLS (.m3u8) and progressive HTTP(S) video
• Files: anything AVFoundation can play, including H.264 and HEVC in MP4, MOV and M4V

YOUR OWN MEDIA SERVER
Point DashCast at a playlist that your home media server or NAS publishes and watch your personal library on the road. DashCast does not provide, host, sell or recommend any streams.

CAR MODE
Car mode uses a big, simple interface with large controls that you can read at a glance. Video goes to the car display only while you are parked or when a passenger is watching. While the car is moving, use audio only.

PLAYLISTS
Add playlists from a URL or the Files app, refresh them with one tap and remove the ones you no longer need. Mark favourites for quick access. Everything stays on your device.

DRIVE, WIDGETS & SOUNDS
• Trip stats: speed, distance, duration and a smooth-driving score, all stored only on your iPhone
• Dashboard widgets and live wallpapers with your car model, a greeting and stickers
• Arrival and connection sounds that you can trigger with Shortcuts automations

PRIVACY
No account. No ads. No tracking. No analytics SDKs. Your playlists, history and trips stay on your iPhone. Location is used on-device to show speed and trip stats and is never uploaded.

DASHCAST PRO
Free to download. DashCast Pro is a one-time purchase that unlocks every feature for life, with no subscription. You can restore your purchase at any time from Settings.

Privacy Policy: https://dashcast.app/privacy
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Support: https://dashcast.app/support

DISCLAIMER
DashCast is a media player only. It does not include or provide any TV channels, playlists or video content. You are responsible for having the rights to the content you add. DashCast is not affiliated with any broadcaster, streaming service or car maker.

SAFETY
For passengers only, or when the vehicle is parked. Never watch video while driving. Follow local laws about screens that the driver can see.
```

*If auto-renewable subscriptions are added, insert before "Privacy Policy":*

```
Subscriptions: DashCast Pro Weekly and Yearly unlock all features for the period shown. Payment is charged to your Apple ID when you confirm the purchase. A subscription renews automatically unless you turn it off at least 24 hours before the current period ends. You can manage or cancel it in Settings → Apple ID → Subscriptions.
```

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

**Notes for the reviewer** (paste into "Notes"):

```
Thank you for reviewing DashCast.

WHAT THE APP IS
DashCast is a video player. It ships with NO channels, playlists or third-party content and does not provide, host or sell any streams. Users add their own M3U/M3U8 playlists, media-server links or video files from Photos/Files.

HOW TO TEST (about 2 minutes)
1. Launch the app and read the passenger-safety notice, then tap "I Understand".
2. On the Cast tab, open "Media Sources", tap "+ Add Playlist" → "From URL" and paste this demo playlist:
   https://dashcast.app/demo/reviewer.m3u
   It lists two open-licence (Creative Commons) Blender Foundation films that we host for review.
3. Tap a channel to play it. Use the AirPlay or screen button to send video to an external display.
4. Optional: Cast → Import → choose any video from Photos.
5. Me → Settings shows Restore Purchases, Privacy Policy, Terms of Use (EULA) and Support.
6. The paywall (Me → "Upgrade Now") shows the one-time price for DashCast Pro. Use the Sandbox account to test.

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

Order: 01 Cast · 02 Car display · 03 Drive · 04 Widgets · 05 Sounds · 06 Me · 07 Paywall.
Every frame has the footer *"For passengers & parked use only. Never watch while driving."*

**Before uploading, check each screenshot** (Guidelines 2.3.3, 2.3.7, 5.2): no third-party logos (Netflix,
Disney+, YouTube…), no copyrighted footage, no "CarPlay" wording and only features that really work.
The Cast and Car-display screens show whatever sample channels the Cast module bundles. See the checklist.

---

## 11. What's New (first version)

```
Welcome to DashCast: your own playlists and videos on the car display, for passengers and parked breaks.
```
