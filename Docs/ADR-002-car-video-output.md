# ADR-002: Car display video output (AirPlay video in the car, mirroring, LAN casting)

**Date**: 2026-11-05
**Status**: Proposed (implemented on `claude/car-video-output`)
**Relates to**: ADR-001 (`fix/CARAA-21-carplay-video-feasibility-adr`). This ADR **updates** ADR-001 where Apple's platform has changed since it was written (see §6).

---

## 1. Context

Two shipping App Store competitors put video on the car display:

- **CarDash**: "plays your videos on compatible CarPlay displays while parked", screen mirroring, built-in browser.
- **CarTV**: screen mirroring to the car display, receives DLNA/UPnP casts, Live Activity while casting.

Apple added "video in the car" to iOS 26 (AirPlay video to the CarPlay display while parked) and, at WWDC26, a CarPlay **video app** category for iOS 27. We need to know which public APIs make car-display video possible on stock iOS, what entitlements each path needs, and the App Review risk of each, then build the feasible parts.

## 2. Findings: what each API actually does

### 2.1 AirPlay video in the car (iOS 26+): `AVPlayer` external playback + `AVRoutePickerView`

- Apple's CarPlay page: *"AirPlay video in the car enables people to watch their favorite videos from iPhone right on their CarPlay display when they aren't driving."* Automakers integrate it through the MFi Program; **each automaker decides whether to allow it**. [developer.apple.com/carplay]
- WWDC26 "Rev up your CarPlay app" (session 212): *"If your app supports AirPlay video streaming, no changes are needed. People can already watch videos from your app on their CarPlay display when they aren't driving. To do so, they simply select the car's display when playing the video on iPhone."*
- Playback is parked-only and the system stops it when the vehicle moves (Cult of Mac, 9to5Mac, TechRadar reporting on the iOS 26 developer note).
- **Car availability is the real limit.** As of early/mid 2026 reporting, no automaker had publicly shipped head-unit firmware with AirPlay video; iOS 26.4 betas showed the system prompt working in a simulated CarPlay environment (9to5Mac, MacDailyNews).
- App side = standard AirPlay video: `AVPlayer.allowsExternalPlayback = true`, `usesExternalPlaybackWhileExternalScreenIsActive = true` (send the stream full-screen instead of mirroring the UI), an `AVRoutePickerView` with `prioritizesVideoDevices = true`, `.playback` audio session with `.allowAirPlay`, and `isExternalPlaybackActive` to show state. **No entitlement needed.**

### 2.2 CarPlay video apps (iOS 27+): `CarPlay.framework` + video entitlement

- WWDC26 session 212: *"with iOS 27 you can create apps to browse and play videos in new cars that support the video in car feature"*. Video apps *"need to support AirPlay video streaming … and use the CarPlay framework to provide a browsing experience on the CarPlay display"*. Browsing uses list/thumbnail templates with `CPPlaybackConfiguration`; playback uses the **system** video player on the car screen (no arbitrary views). *"Apps with the CarPlay video entitlement only appear on the CarPlay home screen if the car supports the video in car feature."* When the car says video is unavailable, playback falls back to audio-only.
- **Entitlement:** a CarPlay video app entitlement requested at developer.apple.com/contact/carplay. An Apple Frameworks Engineer on the Developer Forums (thread 851377) says the CarPlay Developer Guide was updated for iOS 27.2: **audio and video entitlements can no longer be combined**; the CarPlay Audio entitlement now covers apps that mix audio and video. This supersedes the WWDC26 advice to request both.
- Testing: CarPlay Simulator (Additional Tools for Xcode) with a vehicle configuration that supports video.
- **Not built in this change**: it needs an Apple-granted entitlement, the iOS 27 SDK (CI currently selects the newest *non-beta* Xcode on `macos-15`), and a choice between the audio and video entitlement (CARAA-20 currently plans the audio one).

### 2.3 Screen mirroring: ReplayKit Broadcast Upload Extension

- `RPBroadcastSampleHandler` in a Broadcast Upload Extension receives every screen frame system-wide once the user starts a broadcast from `RPSystemBroadcastPickerView` (iOS 12+), with `preferredExtension` set to our extension's bundle id so the picker lists only DashCast. Extensions have a hard memory limit of about **50 MB** (exceeding it gets the extension killed), so frames must be downscaled and not buffered.
- **ReplayKit has no output to a car display.** It only gives us frames; we must send them somewhere. The CarPlay display is not a ReplayKit or `UIScreen` target (ADR-001 is right about this). The places frames can go on stock iOS:
  1. **A browser on the local network**: cars with a built-in browser (Tesla, many Android Automotive cars) and wireless CarPlay "AI box" adapters (Android-based, with a browser) join the iPhone's Personal Hotspot or shared Wi-Fi and open `http://<iphone-ip>:8088`. **Implemented** (MJPEG over HTTP from the extension, `Network.framework` `NWListener`).
  2. An AirPlay receiver: iOS's own Screen Mirroring in Control Center already does this; an app cannot start AirPlay mirroring from a broadcast extension.
- **Entitlements:** none for ReplayKit. Local-network serving needs `NSLocalNetworkUsageDescription` (the user sees the Local Network prompt). Plain TCP unicast does **not** need the multicast entitlement.
- **Protected content:** FairPlay-protected video (Netflix, Disney+, Apple TV…) is blacked out in ReplayKit captures. Mirroring is for the user's own content, web video and the DashCast UI.

### 2.4 DLNA / UPnP renderer (CarTV's "receive casts")

- A UPnP MediaRenderer must answer **SSDP multicast** discovery (239.255.255.250:1900). Since iOS 14 this needs the restricted **`com.apple.developer.networking.multicast`** entitlement, requested from Apple (Account Holder, form asks for an App Store URL, roughly a week's turnaround reported) plus `NSLocalNetworkUsageDescription`, and `NSBonjourServices` for any Bonjour types. Enforcement was tightened again in iOS 16.
- Feasible but **not built in this change**: it needs the multicast entitlement first, plus a SOAP/AVTransport implementation. Recommended as a follow-up once the entitlement is granted. It also only receives casts *to the iPhone*; getting them onto the car display still goes through 2.1 or 2.3.

### 2.5 Live Activity while casting

- ActivityKit Live Activity (`NSSupportsLiveActivities`) rendered by a WidgetKit extension. WWDC25 "Turbocharge your app for CarPlay" brings Live Activities to the CarPlay Dashboard on iOS 26 with no extra work. **No entitlement.** **Implemented.**

## 3. What works on stock iOS today

| Path | Stock iOS | Entitlement | Car requirement | Status in this branch |
|---|---|---|---|---|
| AirPlay video to car (iOS 26) | Yes | None | Automaker must ship AirPlay-video firmware | **Done**: player configured, route picker, live status |
| AirPlay to TVs / AirPlay-capable adapters | Yes | None | AirPlay receiver | **Done** (same path) |
| Wired/external display (`UIScreen` / external scene) | Yes | None | HDMI/USB-C display | Existing `ExternalDisplayManager` |
| Mirroring to car/adapter browser (ReplayKit + LAN HTTP) | Yes | None (Local Network prompt) | Car or adapter with a browser on the hotspot/Wi-Fi | **Done**: `DashCastBroadcast` extension |
| CarPlay video app (iOS 27) | Yes, iOS 27 | CarPlay **video** *or* audio entitlement (not both, per iOS 27.2 guide) | Car with "video in car" | Not built: needs entitlement + iOS 27 SDK |
| DLNA/UPnP renderer | Yes | **Multicast** (restricted) | n/a | Not built: entitlement first |
| Arbitrary video in CarPlay templates / onto the CarPlay screen via `UIScreen` | **No** | n/a | n/a | Not possible (ADR-001 still correct) |

## 4. Decision

1. Use the AirPlay route as the main "video in the car" path: configure the shared `AVPlayer` for external video, show the route picker and live route state. This gets iOS 26 car support for free as automakers ship it.
2. Ship a ReplayKit **Broadcast Upload Extension** (`DashCastBroadcast`) that serves an MJPEG viewer page on port 8088, for cars and adapters with browsers. One-tap start via `RPSystemBroadcastPickerView.preferredExtension`.
3. Enforce **parked only** for every car output path (`ParkedGuard`): GPS speed plus Core Motion automotive activity, with a 10 s hold before video resumes after moving. While moving, the app pauses the player, refuses to start playback while a car output is active, and the broadcast extension ends mirroring with an explanation. Unknown motion state (no permission or simulator) does not block.
4. Show a **Live Activity** (Lock Screen, Dynamic Island, and CarPlay Dashboard on iOS 26) while casting, via a `DashCastCastWidget` extension.
5. Defer the CarPlay video app (iOS 27 entitlement) and the DLNA renderer (multicast entitlement) until Apple grants those entitlements. File both requests now.

## 5. App Review risk

| Item | Risk | Notes and mitigation |
|---|---|---|
| AirPlay external playback | **Low** | Standard AVFoundation. |
| Broadcast Upload Extension serving MJPEG on LAN | **Medium** | Public APIs only (ReplayKit, Network). The risk is how it's presented. Reviewers have rejected apps that just duplicate AirPlay mirroring, and Apple has acted against a CarPlay video app before (heise, 2025). Mitigations: describe it as "show your iPhone on your parked car's browser", never "CarPlay video"; parked-only enforcement; explain the Local Network prompt. |
| `location` background mode used by the parked guard | **Medium** | Guideline 2.5.4 requires the mode to serve a real purpose. The app already uses it for trip tracking; the guard only runs while a car output is active. State this in review notes. |
| Driver distraction (Guideline 1.4, Physical Harm) | **Medium** | No user setting to turn off the parked-only guard; copy says "passengers and parked use only". |
| Metadata (2.3.1) and IP (5.2) | **High if mishandled** | No Netflix/Disney+ or other DRM brands in screenshots; don't claim "works in every CarPlay car". iOS 26 AirPlay video depends on the automaker. |
| CarPlay entitlement mismatch | **Medium** | Never draw video in CarPlay templates. The existing `CarPlaySceneDelegate` stays template-only. |

## 6. Corrections to ADR-001

- *"There is no public CarPlay Video entitlement"*: **no longer true** as of WWDC26 / iOS 27 (CarPlay video app entitlement; not combinable with audio per the iOS 27.2 guide).
- *"zero OEMs have shipped AirPlay video"*: still true as far as public reporting goes (latest found: Feb 2026), but the iOS 26 app-side work costs nothing and is now in place.
- *"Local HTTP server … violates 2.5.1"*: an unofficial **AirPlay receiver/daemon** would. A ReplayKit extension serving a web page over `Network.framework` uses only public APIs. Its risk is presentation and driving safety (§5), not 2.5.1.

## 7. Implementation map (this branch)

- `project.yml`: new targets `DashCastBroadcast` (broadcast upload extension) and `DashCastCastWidget` (WidgetKit Live Activity), app group `group.com.xanderco.dashcast`, embedded as app dependencies. All changes add to the file.
- `DashCast/Features/Cast/Shared/CarCastShared.swift`: app-group keys, Darwin notifications, `BroadcastStatus`, MJPEG/HTTP framing, hotspot/Wi-Fi address. Compiled into the app and the extension.
- `DashCastBroadcast/SampleHandler.swift`, `MirrorStreamServer.swift`: frame downscale (≤1280 px), JPEG at ~12 fps only while a viewer is connected, drop-on-backpressure HTTP server.
- `CarVideoOutputController.swift`: AVPlayer external playback, route/AirPlay detection, broadcast status, parked-only enforcement, Live Activity.
- `ParkedStateEvaluator.swift` / `ParkedGuard.swift`: motion logic (unit tested) and sensor wiring.
- `CarOutputPanelView.swift`: "Car Display" sheet (AirPlay, mirroring URL and viewer count, parked status).
- Device setup needed: register the App Group for all three bundle ids in the developer portal (automatic signing handles this on first device build).

## 8. Sources

- Apple: CarPlay for developers, https://developer.apple.com/carplay/
- WWDC26 session 212, "Rev up your CarPlay app", https://developer.apple.com/videos/play/wwdc2026/212/
- WWDC25 session 216, "Turbocharge your app for CarPlay" (Live Activities/widgets in CarPlay), https://developer.apple.com/videos/play/wwdc2025/216/
- Apple Developer Forums, "Can a single app hold two different CarPlay entitlements (e.g. audio + video)?", https://developer.apple.com/forums/thread/851377
- Apple Developer Forums, multicast entitlement / SSDP on iOS 14.5: https://developer.apple.com/forums/thread/661208, https://developer.apple.com/forums/thread/673062
- Nabto, "Notes about iOS 14.5 and later" (multicast enforcement history), https://docs.nabto.com/developer/platforms/ios/ios145.html
- 9to5Mac, CarPlay video in iOS 26 coverage: https://9to5mac.com/2025/06/12/carplay-video-ios-26/, https://9to5mac.com/2026/02/09/carplay-video-ios-26/
- AppleInsider, "Apple quietly adding video playback to CarPlay in iOS 26", https://appleinsider.com/articles/25/07/21/apple-quietly-adding-video-playback-to-carplay-in-ios-26
- TechRadar, "Apple quietly reveals CarPlay's big video upgrade in iOS 26, but there's a catch", https://www.techradar.com/phones/iphone/apple-quietly-reveals-carplays-big-video-upgrade-in-ios-26-but-theres-a-catch
- Cult of Mac, watch videos on CarPlay, https://www.cultofmac.com/news/watch-videos-on-carplay
- MacDailyNews, CarPlay video feature in iOS 26.4, https://macdailynews.com/2026/02/19/check-out-apples-new-carplay-video-feature-in-ios-26-4/amp/
- heise, "Videos in CarPlay: Apple cracks down on third-party app", https://heise.de/-10358638
- ReplayKit broadcast extension memory limit (50 MB): https://www.forasoft.com/blog/article/how-to-implement-screen-sharing-in-ios-1193
