# DashCast on CarPlay

## What the owner must request from Apple (to appear on a REAL car dashboard)

**Request the CarPlay _Video_ app entitlement: `com.apple.developer.carplay-video` (category "Video").**
*(Supersedes the earlier "request Audio" advice — owner's #1 feature is mirroring the iPhone onto
the CarPlay screen, which is what the competitor's CarPlay app does, and that is a video app.)*

1. Account Holder/Admin of team `96YG38576A` opens <https://developer.apple.com/contact/carplay/>.
2. Category: **Video**. App: DashCast, bundle id `com.xanderco.dashcast`. Paste the justification below
   (same text as ADR-002 §7.3).
3. When Apple approves: *Certificates, Identifiers & Profiles → Identifiers → com.xanderco.dashcast →
   Additional Capabilities* → enable the CarPlay Video capability; let Xcode refresh the profiles.
4. Copy the `com.apple.developer.carplay-video` key from `DashCast/DashCast-Simulator.entitlements`
   into `DashCast/DashCast.entitlements` (use the exact key the granted profile shows if it differs)
   and remove the CI line in "Check CarPlay simulator entitlements" that forbids CarPlay keys in the
   device file.

Facts (ADR-002 §7.2): the key `com.apple.developer.carplay-video` was confirmed by Apple DTS in the
developer forums (thread 838529); Audio and Video **cannot be combined** (thread 851377, iOS 27.2);
a Video app only appears in cars whose head unit advertises video playback ("video in car"), and
playback is **parked only**, through the **system video player** fed by AirPlay/AVPlayer video.
No CarPlay category gives a free drawing window except Navigation (`carplay-maps`) — do not request it.

Ready-to-paste justification (Video):

> DashCast is a parked-use video companion for CarPlay. It lets drivers and passengers browse their own
> video library (local files, their own Jellyfin/Emby servers and playlists they add) on the CarPlay
> display and play it through AirPlay video in the car **only while the vehicle is parked**. DashCast
> already ships AirPlay video support (AVPlayer external playback, AVRoutePickerView with video devices
> prioritised) and a ReplayKit broadcast extension so a parked user can show their own iPhone screen on
> the car display.
>
> We request the CarPlay video app entitlement to provide the browsing experience required for video
> apps: a tab bar with Library, Favorites and Cast list/grid templates, using CPPlaybackConfiguration
> and the system video player. Safety: DashCast enforces parked-only use on its own in addition to the
> system — it watches GPS speed and Core Motion automotive activity and pauses playback and ends screen
> broadcasts as soon as the vehicle moves; the car screen then shows a "paused while moving" message
> and no video. When the car reports that video is unavailable, playback falls back to audio-only as
> required. DashCast does not provide DRM streaming services, does not ship third-party channels, and
> does not show any interactive UI on the car display beyond the CarPlay templates.

## Mirror iPhone → CarPlay screen: how it works (ADR-002 §7.5, built)

1. iPhone: **Cast → Car Display** → turn on **"Mirror to CarPlay screen"** → tap the broadcast button.
   The iOS Screen Broadcast sheet lists only **DashCastBroadcast** (`preferredExtension`) → **Start Broadcast**.
2. The extension (`DashCastBroadcast/SampleHandler.swift`) encodes every ReplayKit frame with
   **VideoToolbox H.264** (`MirrorHLSEncoder`: real-time, low-latency rate control, no B-frames,
   ≤1280×720, 30 fps, 3 Mbit/s, keyframe every 1 s) and cuts **1 s fMP4 segments** with
   `AVAssetWriter` (`.mpeg4AppleHLS`). The last 4 segments live in memory (≈2 MB) and are served by
   the existing local server as **`http://127.0.0.1:8088/hls/live.m3u8`** (`/hls/init.mp4`,
   `/hls/segN.m4s`). The MJPEG browser path (`/`, `/stream`) is unchanged.
3. The app sees the broadcast go live (Darwin notification) and `CarPlayMirrorPlayback` waits for the
   first segment, then plays the playlist in the normal DashCast `AVPlayer` with external playback
   on → that is the system-player route CarPlay video apps use, so a "video in car" CarPlay system
   (or AirPlay video) shows the iPhone screen full screen. On the car screen, **Cast → "Show iPhone
   screen"** does the same and opens Now Playing.
4. **Parked only, everywhere:** `ParkedGuard` (GPS + Core Motion) writes "moving" to the app group;
   the extension ends the broadcast, `CarPlayMirrorPlayback.decide` refuses to start, and playback
   stops when the broadcast ends. Expected delay: ~2–4 s (HLS live edge).

## How to test

**Xcode CarPlay simulator (no entitlement needed).** Simulator builds use
`DashCast/DashCast-Simulator.entitlements` (selected by `CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]`),
which now contains **`com.apple.developer.carplay-video`**. Device/release builds keep
`DashCast/DashCast.entitlements` without any CarPlay key (CI fails if one is added before the grant).

1. On the Mac: `brew install xcodegen` (once), then in the repo `xcodegen generate`.
2. Open `DashCast.xcodeproj` in **Xcode 27** (the video app category needs the iOS 27 CarPlay simulator),
   scheme **DashCast**, any **iPhone simulator**, **Run** (⌘R).
3. Simulator menu **I/O → External Displays → CarPlay**. In the CarPlay window's settings enable video
   playback support if offered (a Video app only appears when the "car" advertises video).
4. Tap **DashCast** → tabs **Library, Favorites, Now Playing, Cast**. Cast shows the 3 steps and
   **"Show iPhone screen"**.
5. ReplayKit broadcasting does not run in the Simulator, so the mirror stream itself cannot be produced
   there. To check playback of the stream path in the simulator, play any HLS URL from Library.
6. On **Xcode 26** (no video category): change the simulator key back to
   `com.apple.developer.carplay-audio` locally to see the template UI. If the icon is missing:
   Clean Build Folder, delete the app, run again, re-open the CarPlay display; check with
   `codesign -d --entitlements - <path to DashCast.app>`.

**Real iPhone (today, no entitlement):** turn on "Mirror to CarPlay screen", Start Broadcast, then in
Safari on the same iPhone open `http://127.0.0.1:8088/hls/live.m3u8` — it should play your screen with
~2–4 s delay. With an AirPlay TV/receiver selected in DashCast's player, the mirror appears there.

**Real car (after Apple grants Video, iOS 27, car with "video in car"):** install a device build with the
key in `DashCast.entitlements`, park, connect CarPlay, open DashCast on the car screen → Cast → follow the
steps → Start Broadcast on the iPhone → the iPhone screen shows on the car display. Drive off: it stops.


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
