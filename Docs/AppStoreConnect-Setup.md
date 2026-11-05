# App Store Connect setup: DashCast 1.0

A click-by-click guide for the owner. Work through it top to bottom in one sitting; it takes about 30 minutes
once the blockers in section 0 are cleared. Everything you need to paste is in a code block, so you can copy it
as is.

Sources this guide was checked against (Session 24, 2026-11-05): `DashCast/Info.plist`,
`DashCast/Resources/PrivacyInfo.xcprivacy`, `DashCast/Resources/DashCastStore.storekit`,
`DashCast/Core/StoreKit/` (`StoreKitManager`, `EntitlementGate`), `DashCast/Core/Legal/LegalLinks.swift`,
`.github/workflows/testflight.yml`, `Docs/QA/testflight.md`, `AppStoreMedia/metadata.md`,
`Docs/AppReview-checklist.md`.

Where this guide and `AppStoreMedia/metadata.md` disagree, **this guide wins**. It uses the product id
`pro.lifetime` (the one in code and in the StoreKit file; `metadata.md` still says `com.dashcast.lifetime`) and the
GitHub Pages URLs.

---

## 0. Blockers found while writing this guide

Fix these before you press "Submit for Review". The setup steps below can be done now; only submission waits.

| # | Blocker | Why it matters | What to do |
|---|---|---|---|
| B1 | `https://xanderco.github.io/iOSCarPlayVideo/support.html` and `privacy.html` return **404** today. There is no `docs/` folder or `gh-pages` branch in the repo yet. | A dead support or privacy URL is a rejection (Guideline 1.5 and 5.1.1). App Store Connect will also refuse to publish the privacy label without a privacy URL. | Publish the two pages (GitHub repo → Settings → Pages), then open both links on your phone. |
| B2 | The app links to `https://dashcast.app/privacy` and `https://dashcast.app/support` (`LegalLinks.swift` lines 7 and 10, and `LifetimePaywallView.swift` line 8). Those are placeholders. | The links inside the app must open the same live pages as the listing. | Change both files to the GitHub Pages URLs in a code session, then build a new TestFlight build. |
| B3 | The **Feedback** screen (Me → Feedback) sends nothing. "Send Feedback" only shows a "Feedback Sent" alert, and the "Add" screenshot button does nothing. | A fake feature is a Guideline 2.1 / 2.3.1 rejection. | In a code session either remove the Feedback row, or make it open a `mailto:` to your support address. Also remove the "Diagnostics sent with feedback" sentence; nothing is sent. |
| B4 | `AppStoreMedia/reviewer-demo.m3u` points to `dashcast.app`, which is not live. | The reviewer must be able to play something. | Not needed any more. Section 6 uses Apple's own public test stream instead. |

---

## 1. Create the app record (about 3 minutes)

Before you start: the bundle id must already exist at developer.apple.com → Certificates, Identifiers & Profiles →
Identifiers. If `com.xanderco.dashcast` is not in the list, add it there first (App IDs → App → Explicit →
`com.xanderco.dashcast`, tick **App Groups** and **In-App Purchase**). While you are there, also register
`com.xanderco.dashcast.broadcast`, `com.xanderco.dashcast.castwidget` and `com.xanderco.dashcast.widgets`, each
with the app group `group.com.xanderco.dashcast`. TestFlight signing fails without them.

1. Go to **appstoreconnect.apple.com** → **Apps**.
2. Click the blue **+** next to "Apps" → **New App**.
3. Fill the form:

   | Field | Value |
   |---|---|
   | Platforms | **iOS** only |
   | Name | `DashCast: M3U Player & Cast` |
   | Primary Language | **English (U.S.)** |
   | Bundle ID | `com.xanderco.dashcast` (pick it from the menu) |
   | SKU | `DASHCAST-IOS-001` |
   | User Access | **Full Access** |

4. Click **Create**.

If the name is taken, use `DashCast: IPTV Player & Cast` (28 characters) and change nothing else.

Spanish comes later. When you are ready: App Information → the language menu at the top right → **Add
Localization** → **Spanish (Mexico)**. Spanish (Mexico) is the one shown in Colombia and the rest of Latin America.
You do not need it for 1.0.

---

## 2. In-App Purchase: DashCast Pro (about 6 minutes)

1. In the app, left sidebar → **Monetization** → **In-App Purchases** → click **+** (or "Create").
2. Fill the dialog and click **Create**:

   | Field | Value |
   |---|---|
   | Type | **Non-Consumable** |
   | Reference Name | `DashCast Pro (Lifetime)` |
   | Product ID | `pro.lifetime` |

   The product id must be exactly `pro.lifetime`. The code (`ProProduct.lifetime`) and the tests look for that
   string. Product ids can never be reused or renamed, so check it twice before you click Create.

3. **Availability**: leave all countries and regions selected.
4. **Price Schedule** → **Add Pricing** → base country **United States** → choose **$19.99** → Next. Keep Apple's
   automatic prices for the other storefronts → Next → **Confirm**.
5. **Family Sharing**: click **Turn On** and confirm. This matches the StoreKit file (`familyShareable: true`) and
   the paywall line "Shared with your family through Family Sharing". Apple does not let you turn it off again
   after this.
6. **App Store Localization** → **+** → **English (U.S.)**:

   Display Name:
   ```
   DashCast Pro
   ```
   Description (45 characters max):
   ```
   Every feature, forever. One payment.
   ```

7. **App Store Localization** → **+** → **Spanish (Mexico)**:

   Display Name:
   ```
   DashCast Pro
   ```
   Description:
   ```
   Todas las funciones. Un solo pago.
   ```

8. **Review Information** → **Screenshot**: upload `02_paywall.png` from the
   `appstore-screenshots-plain` artifact of the **App Store Media** workflow (folder `6.9-inch_1320x2868_plain/`).
   It has to show the paywall with the price. If you don't have the artifact, take a screenshot of the paywall on
   any iPhone (Me → the Pro banner) and upload that.
9. **Review Notes**:
   ```
   DashCast Pro is a single non-consumable purchase, not a subscription. It removes the two free-plan limits: 1 playlist source and 15 minutes of playback per day. To see the paywall, tap the PRO button at the top of the Cast tab, or the Pro banner on the Me tab. Restore Purchases is on the paywall and in Me > Settings. A sandbox account can buy it.
   ```
10. Click **Save** (top right). The status becomes **Ready to Submit**. The first in-app purchase is submitted
    together with the app version, in section 5 step 9.

---

## 3. App Information (about 5 minutes)

Left sidebar → **General** → **App Information**.

### 3a. Basics

| Field | Value |
|---|---|
| Subtitle (English U.S.) | `Car-screen video. Pay once.` |
| Category, Primary | **Utilities** |
| Category, Secondary | **Entertainment** |
| Content Rights | see 3c |
| Age Rating | click **Set Up Age Rating**, see 3b |

Click **Save** at the top right when done.

### 3b. Age rating questionnaire

Answer exactly like this. The reasoning is next to each answer so you can defend it if Apple asks.

**In-app controls**

| Question | Answer | Why |
|---|---|---|
| Parental Controls | No | The app has none. |
| Age Assurance | No | The app has none. |

**Capabilities**

| Question | Answer | Why |
|---|---|---|
| Unrestricted Web Access | **Yes** | The Cast tab has a **Browser** tile (`WebVideoBrowserView`). It opens any website the user types, with no filter. Answering No here is the most common way to get an app pulled after release. |
| User-Generated Content | No | There is no sharing between users. People only see their own playlists and files. |
| Messaging and Chat | No | None. |
| Advertising | No | No ads, no ad SDK. |

**Mature themes, medical or wellness, sexuality or nudity, violence**: answer **None** / **No** to every
question. The app ships no content of its own. The only bundled videos are our two demo clips (Night Drive and
Track Lap).

**Chance-based activities** (gambling, simulated gambling, contests, loot boxes): **None** / **No**.

**Expected result: 18+.** That comes from Unrestricted Web Access alone. If you later remove the Browser tile,
answer No to that question and the rating should fall to 4+ (open decision O1 in the journal).

A note on user-supplied streams: a playlist a user adds can contain anything, but that is the same as the
browser. The rating is about what the app gives access to, and Unrestricted Web Access already covers it. Don't
answer Yes to violence or sexuality because of what users *might* add; Apple asks about content in the app.

### 3c. Content Rights

Click **Set Up Content Rights**.

- "Does your app contain, show, or access third-party content?" → **Yes**.
  Why: the browser shows third-party websites, and users can play their own third-party streams.
- "Do you have all necessary rights to that content or are you otherwise permitted to use it?" → **Yes**.
  Why: the app ships no third-party content. The only bundled media are our own two demo clips. Everything else is
  added by the user, who is responsible for having the rights, and the description and review notes say so.

---

## 4. App Privacy nutrition label (about 4 minutes)

Left sidebar → **General** → **App Privacy**.

1. **Privacy Policy URL** → Edit →
   ```
   https://xanderco.github.io/iOSCarPlayVideo/privacy.html
   ```
   Save. (Blocker B1: the page must be live.)
2. Data Types → **Get Started**.
3. "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this
   app**. Save.
4. Click **Publish** (top right). The label will read **Data Not Collected**.

### Why "Data Not Collected" is the truthful answer

Apple counts data as "collected" only when it leaves the device and the developer (or a partner) can access it.
I checked the code for every way data could leave the phone:

| What | Where in the code | Leaves the device to us? |
|---|---|---|
| Analytics, crash reporting, ads, attribution SDKs | Searched for Firebase, Crashlytics, Sentry, Amplitude, Mixpanel, AppsFlyer, Adjust, Facebook, AdMob, `ASIdentifierManager`, `requestTrackingAuthorization`, `SKAdNetwork`. None found. `Core/Analytics/UsageMetricsManager` is a local stats screen (no networking). | No |
| Purchases | StoreKit 2 only (`StoreKitManager`). Apple handles payment; we get no personal data. | No |
| Location (speed, trip log, automatic trips) | `DriveLocationService`, `AutoTripService`, `ParkedGuard`. Stored in the app's own storage, never sent. | No |
| Motion activity (driving detection, parked guard) | `AutoTripService`, `ParkedGuard`. Used on the device only. | No |
| Camera (QR scan for playlist links) | `PlaylistQRImportView`. Frames are processed on the device, not saved or sent. | No |
| Photos (pick videos to play) | Copied into the app container. | No |
| Network calls | Only to addresses the user enters: playlist URLs (`PlaylistStore`, `CastHomeView`), their own Jellyfin or Emby server (`MediaServerClient`, password in the Keychain), and websites in the browser. We run no server. | No |
| Screen mirror (broadcast extension) | `DashCastBroadcast/MirrorStreamServer.swift` serves the user's own screen as a live stream on the phone itself and on the local network, so the car display or CarPlay player can show it. It goes straight from the iPhone to the user's screen; we never receive it. | No |
| Feedback form | Sends nothing today (blocker B3). | No |

The privacy manifest agrees: `NSPrivacyTracking = false`, no tracking domains, no collected data types.

Revisit the label if you ever add any of these: an analytics or crash SDK, an in-app feedback upload, an account,
or a server of your own. A `mailto:` link that opens the user's Mail app does not change it.

---

## 5. Version page 1.0 (about 7 minutes)

Left sidebar → **iOS App** → **1.0 Prepare for Submission**.

1. **Previews and Screenshots** → iPhone **6.9" Display** → drag in the seven PNGs from the
   `appstore-screenshots-framed` artifact, folder `6.9-inch_1320x2868/`, in file-name order (01 to 07). If App
   Store Connect also asks for 6.5", use folder `6.5-inch_1284x2778/`. Look at each one first: no third-party logos,
   no "CarPlay" wording.

2. **Promotional Text** (170 max):
   ```
   Your own playlists, home server and videos on the car display, for passengers and parked breaks. One payment unlocks everything. No account, no ads, no tracking.
   ```

3. **Description**:
   ```
   Pay once and keep it. DashCast is free to download, and a single purchase, DashCast Pro, removes every limit for good. There is no subscription and nothing to renew.

   DashCast plays what you already have: M3U playlists, live streams, your home media server and the videos on your iPhone. Send them to a connected car display, an AirPlay screen or a TV, and use your iPhone as the remote. It is built for passengers and for parked breaks, like a charging stop.

   DashCast comes with no channels and no content. You add your own.

   PLAY YOUR OWN SOURCES
   • M3U and M3U8 playlists from a link, a file or a QR code
   • Single HLS streams and HTTP video links
   • Jellyfin and Emby servers at home or on the road
   • Videos from Photos and the Files app (MP4, MOV, M4V, H.264 and HEVC)
   • A simple browser for web pages with video you are allowed to watch

   ON THE BIG SCREEN
   • Play on a car display through a compatible adapter, on AirPlay screens or over HDMI
   • Mirror your whole iPhone screen with the system broadcast picker
   • Mark favourites and refresh playlists with one tap

   TRIP LOG
   • Live map, speed, distance and time for every drive
   • Optional automatic trip recording that starts when you start driving
   • A smooth-driving score and a route map coloured by speed

   WIDGETS AND SOUNDS
   • Home Screen and Lock Screen widgets for your car, your last trip and quick playback
   • Dashboard designs with your car, a greeting, plates and countdowns
   • Arrival and connection sounds, with a step-by-step Shortcuts guide

   FREE AND PRO
   Free: one playlist source and 15 minutes of video a day.
   DashCast Pro: unlimited playlist sources and unlimited playback. One payment, shared with your family through Family Sharing, and restorable on all your devices.

   PRIVATE BY DESIGN
   No account, no ads, no tracking. Your playlists, servers, trips and settings stay on your iPhone. Location is used on the device for the trip log and is never uploaded.

   PLEASE NOTE
   DashCast is a player. It does not provide, host or sell channels, playlists or video. You are responsible for having the right to watch what you add. DashCast is not affiliated with any broadcaster, streaming service or car maker.

   Video is for passengers or for when the vehicle is parked. Never watch video while driving, and follow local laws about screens the driver can see.

   Privacy Policy: https://xanderco.github.io/iOSCarPlayVideo/privacy.html
   Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
   ```

4. **Keywords** (100 max; this is 97, no spaces after commas):
   ```
   m3u8,iptv,hls,stream,playlist,tv,passenger,parked,display,media,server,nas,trip,charging,lifetime
   ```
   Words already in the name or subtitle (DashCast, M3U, player, cast, car, screen, video, pay, once) are left out
   because Apple indexes those anyway.

5. **Support URL**:
   ```
   https://xanderco.github.io/iOSCarPlayVideo/support.html
   ```
   **Marketing URL**: leave empty.

6. **Version**: `1.0.0` (matches `CFBundleShortVersionString`).

7. **Copyright**:
   ```
   2026 Xanderco
   ```
   If you sell as an individual rather than a company, use your legal name instead of Xanderco. It should match the
   seller name on your developer account.

8. **Build** → click **Add Build** → pick the latest TestFlight build (section 7). Answer the export compliance
   question if it appears: the app uses only standard HTTPS, and `Info.plist` already says
   `ITSAppUsesNonExemptEncryption = NO`, so the question normally does not appear.

9. **In-App Purchases and Subscriptions** (on the same page, below the build) → click **+** → tick
   **DashCast Pro (Lifetime)** → Done. Without this the purchase is not reviewed and the paywall shows no price in
   review.

10. **App Store Version Release**: choose **Manually release this version**, so you decide the launch moment after
    approval.

11. Leave **Game Center** off. **What's New** is not shown for a first version.

Click **Save**.

---

## 6. App Review Information (about 3 minutes)

Same page, scroll to **App Review Information**.

| Field | Value |
|---|---|
| Sign-In required | **Unticked** (the app has no accounts) |
| First name, last name, phone, email | Your own. Use a phone number that reaches you; Apple calls if they're stuck. |
| Attachment | Optional. A 30 second screen recording of steps 2 to 4 below helps. |

### Demo stream

Use Apple's own public HLS test stream from the developer sample streams. It is free to use for testing, it's
served over HTTPS by Apple, and I checked that it answers (HTTP 200) on 2026-11-05:

```
https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8
```

Backup if Apple ever moves it:

```
https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8
```

The "From URL" dialog accepts a single `.m3u8` stream as well as a playlist; it adds it as one channel and starts
playing it.

### Notes (paste into the Notes box)

```
Thank you for taking the time to review DashCast.

WHAT THE APP IS
DashCast is a video player for content the user already has: their own M3U playlists, HLS streams, home media servers (Jellyfin, Emby) and videos from Photos or Files. The app ships with no channels or third-party content. The only bundled media are two short demo clips we made ourselves.

HOW TO TEST (about 2 minutes, no account needed)
1. Open the app and tap "I Understand" on the passenger safety notice.
2. On the Cast tab, tap "Media Source", then "+ Add Playlist" > "From URL".
3. Paste this Apple developer sample stream and confirm:
   https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8
   It is added as a channel and starts playing.
4. To send video to another screen, use the AirPlay button in the player, or the "Mirror iPhone" tile on the Cast tab.
5. The Drive tab shows the live map and trip log. It asks for location when you open it.

IN-APP PURCHASE
DashCast Pro (pro.lifetime) is one non-consumable purchase, USD 19.99. There is no subscription. The free plan allows 1 playlist source and 15 minutes of playback per day; Pro removes both limits. Open the paywall from the PRO button on the Cast tab or the Pro banner on the Me tab. Restore Purchases is on the paywall and in Me > Settings, next to the Privacy Policy, Terms of Use and Support links.

PASSENGERS AND PARKED USE ONLY
Video in the car is for passengers, or for when the vehicle is parked. A full-screen notice says this on first launch and must be accepted, it can be read again in Me > Settings, and every App Store screenshot repeats it. The app also uses motion activity to pause video on a car display while the car is moving.

CARPLAY
The app contains a CarPlay scene, but we have not been granted a CarPlay entitlement yet (we have applied for the Video category). Without it nothing appears on a car's CarPlay screen, and the app does not claim CarPlay support anywhere in its listing. Please review the iPhone app, AirPlay and external display output.

SCREEN MIRROR AND LOCAL NETWORK
"Mirror iPhone" uses the system broadcast picker. Our broadcast extension serves the screen as a live stream from the iPhone itself (127.0.0.1) and on the local network, so a parked car's display can play it. Nothing goes to us. This is also why the app asks for local network access, together with connecting to the user's own Jellyfin or Emby server.

BACKGROUND LOCATION
The "location" background mode is used only by the optional automatic trip log: when the user grants Always access, the app notices the start of a drive and records the trip. Trips stay on the device. Nothing is uploaded.

APP TRANSPORT SECURITY (NSAllowsArbitraryLoads)
DashCast plays playlists, streams and personal media servers that the user adds. These are very often plain http: public M3U playlists and the streams they list, and home Jellyfin or Emby servers (http://<host>:8096 by default). We cannot know these addresses in advance, so per-domain exceptions are not possible. The app ships no content of its own, and its own links (privacy policy, support) and StoreKit use https.

PRIVACY
No account, no analytics, no ads, no tracking. Location, motion and camera (QR scan) are used on the device only.
```

---

## 7. TestFlight build (about 5 minutes of clicks, then 20 to 40 minutes of waiting)

The repo already has the workflow `.github/workflows/testflight.yml`. It archives, signs with cloud signing and
uploads. Full background is in `Docs/QA/testflight.md`.

### 7a. One-time: create the API key and the three secrets

1. App Store Connect → **Users and Access** → **Integrations** tab → **App Store Connect API** → **Team Keys** →
   **+** (Generate API Key).
2. Name: `GitHub TestFlight`. Access: **Admin** (needed for cloud-managed signing certificates). Click
   **Generate**.
3. Click **Download** next to the new key. You get `AuthKey_XXXXXXXXXX.p8`. Apple only lets you download it once;
   keep it somewhere safe.
4. Note the **Key ID** (10 characters, in the table) and the **Issuer ID** (the UUID above the table).
5. GitHub → `Xanderco/iOSCarPlayVideo` → **Settings** → **Secrets and variables** → **Actions** → **New repository
   secret**, three times:

   | Name | Value |
   |---|---|
   | `ASC_KEY_ID` | the Key ID |
   | `ASC_ISSUER_ID` | the Issuer ID |
   | `ASC_KEY_P8` | open the `.p8` in a text editor and paste all of it, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |

   The team id `96YG38576A` is already in the workflow; it is not a secret.

### 7b. Every build

1. Make sure the branch you build from has the B2 and B3 fixes.
2. GitHub → **Actions** → **TestFlight** (left list) → **Run workflow** → pick the branch → leave both fields empty
   (build number becomes 100 + run number, version stays 1.0.0) → **Run workflow**.
3. Wait for the green tick (about 15 to 25 minutes). If it fails, download the `testflight-logs` artifact and look
   up the error in the table at the end of `Docs/QA/testflight.md`.
4. App Store Connect → the app → **TestFlight** tab. The build shows "Processing" for 5 to 30 minutes, then
   "Ready to Test".
5. **Internal Testing** → **+** → create group `Owner` → add yourself → tick the build. Install **TestFlight** on
   your iPhone and accept the invite.
6. On the phone, before submitting: run the reviewer steps from section 6 exactly as written, buy Pro with a
   Sandbox account (Settings → App Store → Sandbox Account on the iPhone), delete and reinstall, then tap Restore
   Purchases.

---

## 8. Pre-submission checklist

Tick every line before **Add for Review** → **Submit to App Review**.

**Blockers**
- [ ] B1 support and privacy pages are live (open both URLs on your phone).
- [ ] B2 in-app Privacy and Support links open those same pages (Me → Settings → Legal, and the paywall footer).
- [ ] B3 Feedback screen removed or really sends mail.

**Build**
- [ ] CI is green on the branch the build came from.
- [ ] The TestFlight build is installed and the section 6 steps work on a real iPhone, on mobile data and on Wi-Fi.
- [ ] Sandbox purchase works, the limits go away, and Restore brings Pro back after a reinstall.
- [ ] The free limits show the paywall (add a second playlist; play past 15 minutes or trust the unit tests).
- [ ] No placeholder buttons or fake alerts left in any tab (tap through Cast, Drive, Widgets, Sounds, Me).
- [ ] The passenger notice appears on a fresh install.

**App Store Connect**
- [ ] App record: name, bundle id `com.xanderco.dashcast`, SKU `DASHCAST-IOS-001`, English (U.S.).
- [ ] IAP `pro.lifetime`: Non-Consumable, $19.99, Family Sharing on, English and Spanish text, screenshot, review
      note, status Ready to Submit, and attached to version 1.0 (section 5 step 9).
- [ ] Categories Utilities / Entertainment; age rating done (expect 18+); content rights answered.
- [ ] Privacy URL set and label published as Data Not Collected.
- [ ] Screenshots checked: no third-party logos, no copyrighted footage, no "CarPlay".
- [ ] Name, subtitle, keywords and promo text contain no "CarPlay" and no other company's product names.
- [ ] Description, keywords, support URL, copyright filled; Marketing URL empty.
- [ ] Build attached; manual release selected.
- [ ] Review contact details filled with a phone that reaches you; notes pasted; demo stream URL plays.
- [ ] Banking, tax and the Paid Apps agreement are **Active** (Business section of App Store Connect). Without it
      the purchase cannot be reviewed or sold.

After you submit, review usually takes one to two days. If Apple writes back, answer in App Store Connect →
App Review, and log the message in `Docs/JOURNAL.md` so the next session can act on it.
