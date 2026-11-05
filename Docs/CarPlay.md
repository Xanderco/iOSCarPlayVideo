# DashCast on CarPlay

> **Video entitlement request (Session 20):** the full form walkthrough, ready-to-paste answers,
> Apple's checklist and the after-approval steps for the CarPlay **Video** category
> (`com.apple.developer.carplay-video`) are in
> [`Docs/CarPlay-Video-Entitlement-Request.md`](CarPlay-Video-Entitlement-Request.md).
> Video and Audio cannot be combined (CarPlay Developer Guide, October 2026): request one.
> The Audio option below stays valid if the owner prefers DashCast in every CarPlay car.

## What the owner must request from Apple (to appear on a REAL car dashboard)

**Request the CarPlay _Audio_ entitlement: `com.apple.developer.carplay-audio`.**

1. Account Holder/Admin of team `96YG38576A` opens <https://developer.apple.com/contact/carplay/>.
2. Category: **Audio**. App: DashCast, bundle id `com.xanderco.dashcast`. Paste the justification below.
3. When Apple approves: *Certificates, Identifiers & Profiles → Identifiers → com.xanderco.dashcast →
   Additional Capabilities* → enable the CarPlay Audio capability; let Xcode refresh the profiles.
4. Copy the `com.apple.developer.carplay-audio` key from `DashCast/DashCast-Simulator.entitlements`
   into `DashCast/DashCast.entitlements` and remove the CI guard step "Check CarPlay simulator
   entitlements" line that forbids it.

Why Audio and not the iOS 27 Video entitlement: an Audio app shows on the CarPlay home screen of
**every** CarPlay car; a Video app only appears in cars whose automaker ships "video in the car"
(almost none yet), and the two cannot be combined (iOS 27.2). Video on the car screen still works
for an Audio app through AirPlay video while parked (iOS 26). Revisit Video when cars support it
(ADR-002 §7.2). Navigation (`carplay-maps`) is the only entitlement that gives a free drawing
window, but Apple only grants it to turn-by-turn apps: do not request it.

Ready-to-paste justification:

> DashCast is a car companion app. In CarPlay it is an audio app: drivers browse their own live
> channels and playlists (Library, Favorites) and listen to the audio through the car while
> driving, using CPListTemplate, CPTabBarTemplate and CPNowPlayingTemplate with MPNowPlayingInfoCenter
> and remote commands. DashCast never shows video while the vehicle is moving: video goes to the
> car display only through AirPlay video in the car (iOS 26) while parked, and DashCast also stops
> its own playback and screen broadcasts when GPS speed or Core Motion reports driving. The car
> screen shows only standard CarPlay templates. DashCast does not offer DRM streaming services or
> third-party channel presets; users add their own playlists and media servers.

## How to see DashCast on the CarPlay simulator (no entitlement needed)

Simulator builds use `DashCast/DashCast-Simulator.entitlements` (selected by
`CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]` in `project.yml`), which contains
`com.apple.developer.carplay-audio`. Simulator builds are not checked against a provisioning
profile, so the key works there. Device/release builds keep `DashCast/DashCast.entitlements`
without any CarPlay key (CI fails if one is added before the grant).

1. On the Mac: `brew install xcodegen` (once), then in the repo `xcodegen generate`.
2. Open `DashCast.xcodeproj`, scheme **DashCast**, destination any **iPhone simulator**
   (iOS 17+), press **Run** (⌘R).
3. With the Simulator in front: menu **I/O → External Displays → CarPlay**. A CarPlay window opens.
4. On the CarPlay home screen tap the **DashCast** icon (swipe to the 2nd page if needed).
5. You should see the tab bar: **Library**, **Favorites**, **Now Playing**, **Cast**. Tap a Library
   channel → it starts playing and **Now Playing** shows it. **Cast** is the
   "Mirror iPhone" instructions screen (3 steps: open DashCast → Cast → Car Display, turn on
   "Mirror to CarPlay screen" and Start Broadcast, parked only).
6. If the icon is missing: Product → Clean Build Folder, delete the app from the simulator, run
   again, then re-open the CarPlay display (the entitlement is read at install time). Check with
   `codesign -d --entitlements - <path to DashCast.app>` that `carplay-audio` is present.

Limits: ReplayKit broadcasting does not run in the Simulator, so the mirror itself can only be
tried on a device; the CarPlay window renderer (ADR-002 §7.4) is never used by an Audio app.


## Why DashCast does not show up on CarPlay yet

CarPlay only lists apps whose provisioning profile carries a **CarPlay entitlement** granted by Apple.
The code is ready (`DashCast/CarPlay/CarPlaySceneDelegate.swift`, scene roles in `DashCast/Info.plist`),
but until Apple approves the request, the app will not appear on a real car or on the CarPlay
Simulator with a device. Adding the entitlement key yourself before Apple grants it makes code
signing fail ("Provisioning profile doesn't include the com.apple.developer.carplay-… entitlement").

## Requesting the entitlement

1. Sign in as the Account Holder / Admin of team `96YG38576A`.
2. Fill the form at <https://developer.apple.com/contact/carplay/>, category **Audio** (see top).
3. When Apple approves it, in the developer portal open *Certificates, Identifiers & Profiles →
   Identifiers → com.xanderco.dashcast → Additional Capabilities* and enable the granted CarPlay
   capability, then regenerate/refresh provisioning profiles (Xcode Automatic signing does this).
4. Add the key to `DashCast/DashCast.entitlements` (already wired via `CODE_SIGN_ENTITLEMENTS` in
   `project.yml`):

   ```xml
   <key>com.apple.developer.carplay-audio</key>
   <true/>
   ```

   Use the key that matches the granted category (see table).

### Allowed categories and keys

| Category | Entitlement key |
| --- | --- |
| Audio | `com.apple.developer.carplay-audio` |
| Communication (messaging / VoIP) | `com.apple.developer.carplay-communication` |
| Navigation | `com.apple.developer.carplay-maps` |
| EV charging | `com.apple.developer.carplay-charging` |
| Parking | `com.apple.developer.carplay-parking` |
| Quick food ordering | `com.apple.developer.carplay-quick-ordering` |
| Fueling | `com.apple.developer.carplay-fueling` |
| Driving task | `com.apple.developer.carplay-driving-task` |

iOS 27 adds a CarPlay **video app** entitlement (WWDC26), which only shows in cars that support
"video in the car" and cannot be combined with Audio. See ADR-002 §7.

## Testing without a car

- **Xcode iOS Simulator:** see "How to see DashCast on the CarPlay simulator" above (the key is
  committed in the simulator-only entitlements file).
- **CarPlay Simulator (Mac app):** part of *Additional Tools for Xcode* (download from
  developer.apple.com/download/all). Connect an iPhone by USB running a build signed with the
  granted entitlement; the Mac acts as a head unit.

## What the CarPlay scene does

- **Library:** groups (`group-title`) from `PlaylistStore.shared.allChannels`; tapping a group pushes
  its channels.
- **Favorites:** `PlaylistStore.shared.favoriteChannels`, sectioned by group; when empty the
  template's empty view ("No Favorites Yet") is shown.
- **Info:** short explanation.
- Lists respect `CPListTemplate.maximumSectionCount` / `maximumItemCount` (read at connect time,
  they depend on the car), tabs respect `CPTabBarTemplate.maximumTabCount`, and pushes respect the
  5-template depth limit for audio apps (Now Playing counts; if the stack is full it pops to root
  first). Library, Favorites and any pushed group list rebuild on
  `PlaylistStore.didChangeNotification`.
- Selecting a channel calls `VideoPlayerService.shared.load(channel:)` and shows
  `CPNowPlayingTemplate.shared`. `MPNowPlayingInfoCenter` (title, group, live, rate) and the
  rows' playing indicator follow `VideoPlayerService`'s `currentChannel` / `isPlaying`, so they stay
  right when playback is changed from the iPhone. `MPRemoteCommandCenter` play / pause / toggle are
  wired while CarPlay is connected and removed on disconnect.
- All CarPlay code is `@MainActor` (the scene delegates, template handlers, notification and
  Combine callbacks via `MainActor.assumeIsolated` on the main queue).

## Video in the car (iOS 26)

iOS 26 adds "video in the car" only **while parked**, and only via **AirPlay** to head units whose
automaker supports it. It is not part of the CarPlay template API and needs no extra entitlement:
DashCast's AirPlay route picker covers it. While driving, CarPlay gets audio + Now Playing only.
