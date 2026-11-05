# DashCast on CarPlay

## Why DashCast does not show up on CarPlay yet

CarPlay only lists apps whose provisioning profile carries a **CarPlay entitlement** granted by Apple.
The code is ready (`DashCast/CarPlay/CarPlaySceneDelegate.swift`, scene roles in `DashCast/Info.plist`),
but until Apple approves the request, the app will not appear on a real car or on the CarPlay
Simulator with a device. Adding the entitlement key yourself before Apple grants it makes code
signing fail ("Provisioning profile doesn't include the com.apple.developer.carplay-… entitlement").

## Requesting the entitlement

1. Sign in as the Account Holder / Admin of team `96YG38576A`.
2. Fill the form at <https://developer.apple.com/contact/carplay/>. Choose the category that matches
   what the app does in the car (for DashCast: **Audio**, since live channels play as audio while
   driving).
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

There is no "video" category: CarPlay templates cannot play video while driving.

## Testing without a car

- **Xcode iOS Simulator:** run the app, then *I/O → External Displays → CarPlay* in the Simulator
  menu. For the simulator you can temporarily add the entitlement key locally (simulator builds are
  not checked against a profile); do not commit it before Apple grants it.
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
