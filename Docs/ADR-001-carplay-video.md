# ADR-001: Technical & Legal Feasibility of In-Car Video & Apple CarPlay Capabilities

**Date**: 2026-11-05  
**Status**: Accepted  
**Deciders**: Alexander Benitez (Human Owner & Sole Approval Authority), Chief Executive Officer (CEO), Principal iOS & CarPlay Systems Engineer (CTO)

---

## 1. Context & Problem Statement

DashCast Inc. (`CARAA`) set out to disrupt the automotive utility space with a $19.99 Lifetime Access model (zero subscriptions), replacing predatory competitors (CarDash, CarTV, PlayCar) who charge $9.99/month. A central pillar of competitor marketing and early DashCast ideation was "casting video to Apple CarPlay" (YouTube, IPTV, Netflix, local video).

However, rigorous technical and legal audit reveals deep architectural constraints imposed by Apple, vehicle safety standards, and intellectual property law that render "arbitrary video rendering on native Apple CarPlay head units" impossible on stock, non-jailbroken iOS devices:

1. **CarPlay Framework Template Constraints**:
   - `CarPlay.framework` is strictly template-driven (`CPTemplateApplicationSceneDelegate`). Approved public templates (`CPTabBarTemplate`, `CPGridTemplate`, `CPListTemplate`, `CPNowPlayingTemplate`, `CPInformationTemplate`, `CPAlertTemplate`) do not allow embedding `UIView`, `AVPlayerLayer`, `UIWindow`, or arbitrary Metal/OpenGL render buffers on the head-unit screen.
   - Apple restricts CarPlay to predefined categories: Audio, Navigation, EV Charging, Parking, Quick Ordering, and Messaging. There is **no public CarPlay Video entitlement** (`com.apple.developer.carplay-video`) available to third-party developers.
   - These constraints are strictly enforced by Apple and international road safety regulators (NHTSA in the US, UNECE in Europe) to prevent in-motion driver distraction.

2. **iOS 18 / iOS 26 "Video in the Car" Reality**:
   - At WWDC, Apple announced parked video casting over AirPlay. However, this feature strictly requires:
     1. Automaker OEM integration into the vehicle's head-unit firmware and telematics gateway.
     2. Hardwired vehicle gear status detection (`gear == .park`).
     3. As of late 2024–2026, **zero major automotive OEMs have publicly shipped production vehicle firmware supporting AirPlay Video receiver endpoints on dashboard head units**.

3. **ReplayKit Public API Limits**:
   - `ReplayKit.framework` (`RPScreenRecorder`, `RPBroadcastActivityViewController`) allows broadcasting the iOS screen to streaming endpoints (RTMP/Twitch) or capturing screen buffers locally.
   - ReplayKit **cannot target an external Apple CarPlay display**. CarPlay is not exposed as a `UIScreen` or `UIWindowScene` destination for ReplayKit broadcasts via public APIs.

4. **FairPlay DRM & App Store Legal Compliance**:
   - Tier-1 video providers (Netflix, Amazon Prime Video, Disney+, Max/HBO, Apple TV+) protect their streams with Apple FairPlay Streaming (FPS) DRM.
   - Attempting to capture, mirror, or proxy FairPlay content causes the hardware decoder to render black frames (pure black pixels) by cryptographic design.
   - Promoting trademarked streaming services (Netflix, Disney+) as "castable to CarPlay" directly violates **App Store Review Guideline 5.2 (Intellectual Property)** and **Guideline 2.3.1 (Misleading Metadata)**, triggering immediate app rejection or developer account termination.

5. **Competitor Deconstruction & Grey Market Practices**:
   - **Jailbreak Daemons (e.g. CarBridge)**: Patch `CarPlayDaemon` and `SpringBoard` on jailbroken iPhones. Incompatible with stock iOS; cannot be distributed via the App Store.
   - **Aftermarket AI Android Boxes (e.g. Carlinkit, Ottocast)**: Physical USB dongles containing standalone Android systems that impersonate CarPlay to the head unit and run Android apps independently. They do not run on the user's iPhone.
   - **Storefront Scams / Bait-and-Switch Apps**: Competitor apps that display fake mockup screenshots of video casting on CarPlay, but in reality only open mobile web bookmarks on the phone screen or crash. These apps accumulate 1-star reviews and are purged by Apple App Review.

---

## 2. Decision

DashCast will not pursue deceptive marketing, illegal hacks, or technically impossible features. We commit to a **100% Stock iOS Compliant, App Store Approved, 5-Star Architectural Strategy**:

### Pillar A: In-Dash CarPlay Audio & Media Station (`CarPlay.framework`)
- Apply for the standard, approved **`com.apple.developer.carplay-audio`** entitlement.
- Implement native CarPlay templates (`CPTabBarTemplate`, `CPListTemplate`, `CPNowPlayingTemplate`) for in-dash browsing and control:
  - **M3U IPTV & Radio Audio Streaming**: Play audio feeds of news, sports, music, and user-imported IPTV channels directly through the car's sound system.
  - **Ambient In-Cabin Soundboard**: One-touch playback of vehicle connection sounds, engine chimes, and ambient soundscapes.
  - **Full Remote Transport & Metadata**: Complete `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` integration displaying track titles, artwork, and scrub controls on the in-dash screen.

### Pillar B: Phone-Side Landscape Theater Mode (Mounted iPhone)
- The iPhone is mounted on a MagSafe or dashboard mount during parked charging, resting, or drive-in scenarios.
- DashCast provides an **OLED True Black high-contrast automotive video player**:
  - Full-screen playback of local videos, user-imported M3U/M3U8 streams, and supported web streams.
  - Car-grade touch targets (minimum 48×48pt) with glare-safe yellow typography (`#FFE600`).
  - Seamless vehicle audio routing over Wireless CarPlay / Bluetooth / USB.
  - **Native AirPlay Route Picker (`AVRoutePickerView`)**: Drivers with vehicles, rear-seat entertainment monitors, or aftermarket HDMI adapters that support AirPlay Video can seamlessly route video to those external displays via native iOS APIs.

### Pillar C: Driving Telemetry, Dynamic Island Live Activities & Widgets
- Real-time GPS speedometer, G-force friction circle, and drive smoothness scoring (`SmoothnessScorer.swift`).
- Dynamic Island and Lock Screen Live Activities (`ActivityKit`) providing persistent driving metrics.
- In-dash customization widgets (analog tachometer clocks, license plate badges, trip stat counters).
- Post-drive summary scorecards with viral social export templates.

---

## 3. Product Roadmap & Backlog Rescoping Matrix

To align our engineering execution with this architectural decision, the Paperclip issue backlog is triaged as follows:

| Issue ID | Original Title | Feasibility Assessment | Architectural Action / Rescoped Scope |
| :--- | :--- | :--- | :--- |
| **CARAA-21** | `[CEO] Feasibility decision: what 'casting to CarPlay' can legally/technically be` | Complete | **Accepted**. ADR-001 authored. Roadmap and issue backlog officially rescoped. |
| **CARAA-20** | `[HUMAN] Request CarPlay entitlement from Apple + add entitlements file` | Feasible (Audio) | **Rescoped**. Request `com.apple.developer.carplay-audio` (approved public audio category), NOT video. Add `.entitlements` file. |
| **CARAA-22** | `[CarPlay] Library tab uses hardcoded sample playlist — wire to user's imported M3U playlists` | 100% Feasible | **Approved**. Wire `CPListTemplate` to `IPTVParser` user-imported channels for audio streaming in CarPlay. |
| **CARAA-23** | `[M3U] Robust M3U/M3U8 import: file picker, URL, persistence, errors` | 100% Feasible | **Approved**. Core media library management for both phone-side theater mode and CarPlay audio streams. |
| **CARAA-24** | `[Browser] 'Send to car' is a fake alert; browser has no real casting` | Misleading Concept | **Rescoped**. Replace fake "Send to car" alert with **"Play in DashCast Theater"**: Extract HLS/MP4 video URL via `WKUserScript`, open in automotive player on iPhone, route audio to car speakers, and enable native `AVRoutePickerView` for AirPlay receivers. |
| **CARAA-14** | `[DI-21] [CastEngine] Offline Deadzone Cache & Local Media Preloader` | 100% Feasible | **Approved**. Preloads and caches user streams for uninterrupted playback through deadzones and tunnels. |
| **CARAA-15** | `[DI-22] [UX] Offline Media Library, Cache Storage Status & Preloader Controls` | 100% Feasible | **Approved**. Driver garage storage quota management and offline library. |
| **CARAA-16 / 17** | `[DI-23/24] Drive Summary Card Image Renderer & Social Share Templates` | 100% Feasible | **Approved**. Viral post-drive score cards and TikTok/Instagram share sheets. |
| **CARAA-3** | `[DI-7] Cast Module 1:1 Pixel Match, Native CarPlay Scene & In-App Emulator` | Legacy Wording | **Updated**. Clarify that native CarPlay scene hosts audio/telemetry/now-playing, while video theater mode runs on phone with AirPlay route options. Remove all DRM provider logos (Netflix, Disney+) from marketing materials. |

---

## 4. Alternatives Considered & Rejected

### Alternative 1: Jailbreak Daemon Patching (CarBridge Method)
- **Mechanism**: Inject dylibs into `CarPlayDaemon` to remove window restrictions.
- **Why Rejected**: Requires jailbreaking the iPhone. Incompatible with 99.9% of consumer iPhones, zero possibility of App Store distribution, violates Apple Developer Program License Agreement.

### Alternative 2: Reverse-Engineered Wireless AirPlay Server Emulation
- **Mechanism**: Run a local HTTP server / unofficial AirPlay mirroring daemon inside the app.
- **Why Rejected**: AirPlay mirroring to CarPlay is not supported by public head-unit firmware; unauthorized screen streaming violates App Store Review Guideline 2.5.1 and results in immediate App Store removal.

### Alternative 3: Fake Video Casting / Marketing Deception (Storefront Scam Method)
- **Mechanism**: Show mockups of Netflix/YouTube streaming onto car screens in App Store screenshots and promotional videos, while delivering only bookmarks or audio in-app.
- **Why Rejected**: Violates Apple App Store Review Guidelines 2.3.1 (Misleading App Metadata) and 5.2 (Intellectual Property). Guarantees 1-star user revolt, refund spikes, and permanent developer ban. DashCast's core thesis is extreme authenticity and lifetime value.

---

## 5. Consequences & Trade-Offs

### Positive
- **Guaranteed App Store Approval**: Using standard `com.apple.developer.carplay-audio` and public `CarPlay.framework` templates ensures zero friction during App Store review.
- **Zero DRM Litigation Risk**: Eliminating misleading Netflix/Disney+ claims protects DashCast from IP infringement lawsuits and copyright strikes.
- **Rock-Solid User Trust & Retention**: Users receive exactly what is advertised: a premium, high-speed, lag-free in-car audio and video companion, without fake promises.
- **Superior Audio Quality**: In-cabin vehicle audio routes cleanly through wireless CarPlay without video encoding latency or frame dropping.

### Negative & Trade-offs
- Users expecting video directly on their in-dash display must be educated that Apple does not permit arbitrary third-party video on CarPlay screens while driving.
- Video playback is centered on the dashboard-mounted iPhone screen (or external AirPlay video displays when supported).

### Risks & Mitigations
- **Risk: User expectation mismatch regarding "CarPlay Video"**:
  - *Mitigation*: Transparent marketing copy in onboarding and App Store description: *"Stream your favorite M3U channels, web media, and custom car audio with seamless vehicle sound integration. Watch video in full-screen theater mode on your mounted iPhone, with synchronized in-dash CarPlay audio controls and AirPlay display support."*
- **Risk: Rejection of CarPlay Audio Entitlement request**:
  - *Mitigation*: Ensure the app functions completely standalone on iPhone, and properly integrates `MPNowPlayingInfoCenter` and `CPTemplateApplicationSceneDelegate` strictly conforming to Apple's CarPlay Audio App guidelines.
