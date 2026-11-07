# DashCast on CarPlay

> **Video entitlement request (Session 20):** the full form walkthrough, ready-to-paste answers,
> Apple's checklist and the after-approval steps for the CarPlay **Video** category
> (`com.apple.developer.carplay-video`) are in
> [`Docs/CarPlay-Video-Entitlement-Request.md`](CarPlay-Video-Entitlement-Request.md).
> Video and Audio cannot be combined (CarPlay Developer Guide, October 2026).

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

Ready-to-paste justification (Video): **use `Docs/CarPlay-Video-Entitlement-Request.md` §1 and §2**
(Session 20). It replaces the earlier text that was here: that text said "drivers", described
showing the iPhone screen on the car display and used marketing phrasing, which are the things most
likely to get a CarPlay request refused. The new doc also lists every form field, Apple's checklist
and the after-approval steps.

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

## Widgets on the car display (iOS 26)

Since iOS 26, CarPlay can show the iPhone's **`.systemSmall`** widgets on the car display, even for apps without a CarPlay entitlement ([WWDC25 session 216](https://developer.apple.com/videos/play/wwdc2025/216/)). Small widgets can open the app, and on touchscreen cars they're interactive. This works independently of the CarPlay app entitlement described above.

DashCast's `DashCastWidgets` extension is eligible:

| Widget | Families | CarPlay |
|---|---|---|
| My Car (`DashCastCarWidget`) | small, medium | small is eligible |
| Last Trip (`DashCastTripStatsWidget`) | small, medium | small is eligible |
| Quick Cast (`DashCastQuickCastWidget`) | small + Lock Screen accessories | small is eligible, opens `dashcast://cast` |
| Photo / Doodle (`DashCastDoodleWidget`) | small | eligible; set up via Widgets → "Photo / Doodle widget" |

Rules (enforced by code review; see `GlanceContext` in `DashCastWidgets/DashCastWidgetsBundle.swift`):
- **Never** add `.disfavoredLocations([.carPlay], for: [.systemSmall])`. That modifier is Apple's opt-out: it moves a widget into the "not optimized for CarPlay" group in CarPlay Settings.
- Always provide `.containerBackground(_:for: .widget)`. Content also reads `showsWidgetContainerBackground` so it still works if the system removes the backdrop.
- WidgetKit has no CarPlay-specific environment value. Layouts instead adapt to `widgetRenderingMode`: in `.accented` or `.vibrant` mode (tinted or dimmed displays) text switches to system `.primary` and `.secondary` styles, key glyphs use `widgetAccentable()`, and meaning never depends on colour alone (for example, the score shows a checkmark or warning icon as well as its colour).
- Use large, heavy, rounded type (20–44 pt for key values) with one fact per widget. The user's accent colour is passed through `WidgetColorMath.readableAccentHex`, which falls back to the brand teal unless it reaches a 4.5:1 WCAG contrast ratio on the dark backdrop. This is unit-tested in `WidgetSharedStoreTests`.

### Seeing them in the CarPlay simulator

1. Build and run DashCast on an **iOS 26** iPhone simulator (Xcode 26). Open the app once so it writes the app-group snapshot. Edit a widget and record or seed a trip (or launch with `-seedDemoData`, which runs `DemoDataSeeder`) so there's data to show.
2. On the simulator Home Screen, long-press → **Edit → Add Widget → DashCast** and add the small widgets. CarPlay offers the widgets the phone supports, but adding them on the phone first is the quickest way to confirm they render.
3. In the Simulator menu choose **I/O → External Displays → CarPlay**. The CarPlay window opens.
4. In the CarPlay window, swipe to the widget page (left of the Dashboard). Use **Edit** (long-press) to add DashCast widgets. They're also listed in **Settings → CarPlay → [car] → Widgets** on the phone. Our widgets must *not* appear under "Not optimized for CarPlay"; if they do, someone added `disfavoredLocations`.
5. To check the car's dimmed and night styles, toggle Simulator **Features → Toggle Appearance** and check the text is still readable in each style.
6. For a real head unit, use Apple's **CarPlay Simulator** app (Additional Tools for Xcode) with a physical iPhone on iOS 26 connected over USB.

Not yet verified on a physical car; please add screenshots under `Screenshots/` once captured.
