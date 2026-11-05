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
