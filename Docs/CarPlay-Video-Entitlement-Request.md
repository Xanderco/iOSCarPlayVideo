# CarPlay Video entitlement request (DashCast)

Session 20, 2026-11-05. Everything the Account Holder or Admin of team `96YG38576A` needs to fill
Apple's CarPlay entitlement form for the **Video** category, plus what Apple checks and what to
change in the repo after approval.

> **Read first: Video replaces Audio.** The CarPlay Developer Guide (October 2026, p. 4) says
> "Multiple categories cannot be combined in a single app, with the exception of EV charging and
> fueling apps", and Apple confirmed for iOS 27.2 that "the CarPlay Audio App and CarPlay Video
> App entitlements cannot be combined in the same app" (forums thread 851377). With the Video
> entitlement DashCast **only appears in cars that support video in CarPlay** (guide p. 4: "Video
> apps are hidden in vehicles that do not support video playback in CarPlay"). The owner chose
> Video in Session 19 (journal O4). Request Video only, never Audio and Video together.
> This document replaces the justification that was in `Docs/CarPlay.md` and ADR-002 §7.3.

## 0. Before you submit

- [ ] Sign in at <https://developer.apple.com/contact/carplay/> as Account Holder or Admin of
      team `96YG38576A` (the form redirects to the Apple ID sign-in; it cannot be filled without it).
- [ ] App ID `com.xanderco.dashcast` exists under Certificates, Identifiers & Profiles.
- [ ] A working build exists (TestFlight is fine). Apple is reluctant to grant CarPlay to an app
      that is not built yet.
- [ ] Read the CarPlay Entitlement Addendum; you must accept it on the form.
- [ ] Do not mention screen mirroring or the broadcast extension anywhere on the form (see §4).

## 1. Form fields and the exact answers to paste

The form sits behind Apple ID sign-in, so the labels below come from Apple's guide ("provide
information about your app, including the category of entitlement that you are requesting") and
public reports, not from a scrape of the live form. Match each answer to the field with the same
meaning. Apple does not publish the text limits; every answer below is under 1,000 characters,
and the longest (the justification) is about 950. If a box is shorter, use the short version in §2.

| Field | Answer to paste |
|---|---|
| Name, email, team | Prefilled from the signed-in account. Team ID `96YG38576A`. |
| App name | `DashCast` |
| Bundle ID | `com.xanderco.dashcast` |
| Apple ID / App Store URL (if asked) | The App Store Connect Apple ID of DashCast. If there is no public App Store URL yet, write: `Not on the App Store yet. Testing in TestFlight.` |
| Is the app available on the App Store? | Answer truthfully (today: No, TestFlight). |
| Countries / regions (if asked) | `All App Store countries` |
| CarPlay app category / entitlement | **Video** (`com.apple.developer.carplay-video`, iOS 27). Select only Video. |
| App description (what the app does) | See 1a. |
| How will your app work in CarPlay? | See 1b (or paste the full justification from §2 into one box if the form has only one). |
| Safety / driver distraction (if asked separately) | See 1c. |
| Anything else / comments | See 1d. |
| CarPlay Entitlement Addendum | Tick to accept. |

### 1a. App description

```
DashCast is a video player for iPhone. You add your own videos: files on the phone, playlist links or files you already have, and your own Jellyfin or Emby server. The app comes with no videos and no channels. It plays to AirPlay screens today using the standard AVPlayer.
```

### 1b. How DashCast uses CarPlay

```
On the car screen DashCast shows a tab bar with two lists, Library and Favorites. Library shows the user's sources and the videos inside them. Favorites shows the videos they starred on the phone. Each row has a thumbnail and a title. Tapping a row starts the video in the system video player over AirPlay. I only use the CarPlay templates. I do not draw my own player or any custom view on the car screen. Everything in CarPlay can be done on the car screen without touching the phone.
```

### 1c. Safety

```
Video only plays when the car allows it, which means parked. DashCast also checks GPS speed and Core Motion on the phone. If the car starts moving, DashCast pauses the video. If the car says video is not available, the same item keeps playing as audio only, with normal play and pause controls. There are no games, no web pages, no messages and no text input on the car screen.
```

### 1d. Anything else

```
DashCast does not include DRM streaming services and does not ship any third-party content, channel lists or logos. Users only play videos they add themselves.
```

## 2. The justification (single box version)

Use this when the form has one large text field ("Tell us about your app" or similar). Plain,
first person, no lists, no em dashes. About 950 characters.

```
I make DashCast, a video player for iPhone. People add their own videos: files on the phone, playlist links they already have, and their own Jellyfin or Emby server. The app ships with no videos and no channels.

I want DashCast in CarPlay as a video app so someone in a parked car can pick a video from their own library on the car screen and watch it there. The car screen has a tab bar with two lists, Library and Favorites. Each row has a thumbnail and a title. Tapping a row plays the video in the system video player over AirPlay. DashCast already supports AirPlay video. I only use the CarPlay templates and do not draw anything custom on the car screen.

Video only plays when the car allows it. I also check GPS speed and Core Motion on the phone, and if the car starts moving DashCast pauses the video. If the car says video is not available, the same item keeps playing as audio only.

DashCast has no DRM streaming services, no games and no web browsing in CarPlay.
```

Short version (if a box is limited to about 500 characters):

```
I make DashCast, a video player for videos people add themselves: files, playlists they own, and their own Jellyfin or Emby server. It ships no content. In CarPlay it shows Library and Favorites lists, and tapping a row plays the video in the system player over AirPlay, only when the car is parked. I also pause on GPS speed and Core Motion. If the car says video is unavailable, it plays as audio only.
```

## 3. What Apple checks and how DashCast meets it

Source: CarPlay Developer Guide, October 2026, "Guidelines for all CarPlay apps" and
"Additional guidelines for CarPlay video apps", plus WWDC26 session 212. Status is honest:
**Done** means it is in the code on `claude/classic-ui`; **To do** must land before the build
that ships with the entitlement (Apple and App Review can check both).

| What Apple checks | How DashCast meets it | Status |
|---|---|---|
| Video app is "designed primarily to provide video playback services" (video guideline 1) | DashCast is a video player; the CarPlay scene only lists the user's videos. Describe nothing else on the form. | Done (product). |
| Video app supports AirPlay video streaming (video guideline 2) | `AVPlayer.allowsExternalPlayback = true` and `usesExternalPlaybackWhileExternalScreenIsActive = true` in `VideoPlayerService.swift`, `VideoPlayerService+External.swift`, `CarVideoOutputController.swift`. AirPlay route picker in Car Display. | Done. |
| Playback only while parked | The car enforces it. On top, `ParkedGuard` (`DashCast/Features/Cast/ParkedGuard.swift`) reads GPS speed and Core Motion automotive activity, `ParkedStateEvaluator` decides (unit tested), and `CarVideoOutputController` pauses playback and ends broadcasts when moving. | Done. |
| System video player, no custom drawing | Video plays through AVPlayer external playback into the CarPlay system player. The `CPWindow` renderer in `CarPlayMirrorController.swift` never runs: iOS gives a window only to navigation apps. | Done. |
| Templates only, used for their purpose (guideline 7); only allowed templates (Audio/video column: action sheet, alert, grid, list, tab bar, now playing, voice control and search on iOS 27) | `CarPlaySceneDelegate.swift` uses `CPTabBarTemplate`, `CPListTemplate`, `CPNowPlayingTemplate`, respects `maximumTabCount`, `maximumItemCount`, `maximumSectionCount` and the template depth limit. No `CPInformationTemplate`. | Done. |
| Playback state on items (`CPPlaybackConfiguration`: preferred presentation video, elapsed time, duration, play/pause action) and a Videos tab only when `CPSessionConfiguration` says video is supported (WWDC26 212) | Not built yet. Add `CPPlaybackConfiguration` on Library and Favorites rows, keep it in sync with `VideoPlayerService.isPlaying`, check the session configuration. | **To do** (iOS 27 SDK). |
| Audio fallback: "the car may indicate that video playback is not available. If this happens your video will be played as audio-only" | The system does the switch. DashCast already publishes `MPNowPlayingInfoCenter` and remote play/pause, so the audio-only state has a working Now Playing screen. Verify on the CarPlay Simulator with video turned off. | Done in code; **verify**. |
| Never tell people to pick up the iPhone (guideline 2); all flows possible without the iPhone (guideline 3) | Two places break this today in `CarPlaySceneDelegate.swift`: the "Mirror iPhone" Cast tab lists steps to do on the iPhone ("Open DashCast on your iPhone", "starts after Start Broadcast on iPhone"), and the empty states say "Import an M3U playlist on your iPhone" / "Tap the heart ... on your iPhone". Reword empty states to state the condition only (for example "No videos yet" / "No favorites yet"). For the mirror tab the owner must choose: hide it in the Video build, or keep only "Show iPhone screen" without phone instructions and accept the review risk. It is the most likely thing for App Review to flag. | **To do (owner decision for the mirror tab).** |
| Only features related to the primary task (guideline 4); no games or social (guideline 5); no message content (guideline 6) | CarPlay shows Library, Favorites, Now Playing and the Cast tab. No settings, browser, Drive, Widgets or Sounds on the car screen. | Done (Cast tab: see row above). |
| No DRM services, no third-party content (App Review 5.2, journal D5) | DRM presets removed from the browser (#15); no bundled channels or logos; users add their own sources. The demo content is the project's own videos. | Done. |
| Subtitles and audio languages when available (WWDC26 212) | The system player menus show the tracks AVPlayer exposes from HLS. Nothing to build; mention nothing. | Done (system). |
| A real, working app (common refusal reason) | Classic UI build with playlists, Jellyfin/Emby, AirPlay, CarPlay scene, tests green in CI. | Done. |

## 4. What not to say

- Do not write "mirror", "screen mirroring", "show any app", "your iPhone screen on the car" or
  anything about the ReplayKit broadcast. Showing the whole iPhone screen means showing other
  apps' content, which reads as a way around the templates, the parked rule and other apps' rights.
  The entitlement is granted for what the app is primarily for: playing the user's own videos.
  The mirror (Session 19, HLS through the system player, parked only) is a decision for the build
  that ships, see §3, not something to sell in the request.
- Do not name Netflix, YouTube, Disney+, Prime Video, Twitch or any other service, even as
  "not supported". Do not say "IPTV" or "live TV channels"; say "playlists they already have".
- Do not write "watch while driving", "on the road", "during the trip", "keep the kids busy while
  you drive" or anything that puts video and driving in one sentence. Write "parked" and
  "passengers" only where it describes a restriction.
- Do not ask for Audio and Video together, and do not mention Navigation or a custom window.
- Do not say DashCast "bypasses", "unlocks" or "enables" video in cars that do not support it.
- Do not promise features that are not built (casting from a web browser in CarPlay, downloads,
  live sports).
- No marketing words: "seamless", "robust", "leverage", "elevate", "delve", "cutting-edge",
  "immersive", "next-level", "experience" as a noun used for effect.

## 5. After Apple approves

1. Apple emails the Account Holder. In the developer portal: *Certificates, Identifiers &
   Profiles → Identifiers → `com.xanderco.dashcast` → Capabilities / Additional Capabilities* →
   enable **CarPlay Video App**, then **Save**.
2. Refresh provisioning: *Profiles* → regenerate (or create) the development and App Store profiles
   for `com.xanderco.dashcast`, download them, or let Xcode refresh them (Xcode → Settings →
   Accounts → Download Manual Profiles). The guide's example uses manual signing; if automatic
   signing does not pick the key up, switch the DashCast target to manual for that build.
3. Add the key to `DashCast/DashCast.entitlements`, inside `<dict>`, next to the app group:

   ```xml
   <key>com.apple.developer.carplay-video</key>
   <true/>
   ```

4. `DashCast/DashCast-Simulator.entitlements` already carries `com.apple.developer.carplay-video`
   (Session 19). Nothing to change there.
5. In `.github/workflows/ci.yml`, step "Check CarPlay simulator entitlements": delete the
   `if grep -q 'com.apple.developer.carplay' DashCast/DashCast.entitlements` block (it fails the
   build when the device file has a CarPlay key), and add
   `/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.carplay-video' DashCast/DashCast.entitlements`
   so CI checks the key is there.
6. Land the **To do** rows from §3 (empty-state wording, the mirror tab decision,
   `CPPlaybackConfiguration`, video session check). Video apps need the iOS 27 SDK.
7. Verify: `codesign -d --entitlements - DashCast.app` shows `carplay-video`; CarPlay Simulator
   (Additional Tools for Xcode) with a device, video on and off; then TestFlight in a car with
   video in CarPlay support.
8. Only after that, update App Store metadata (journal D6 allows "CarPlay" once the entitlement is
   granted) and add a note to the review notes saying the car must be parked for video.

## Sources

- CarPlay Developer Guide, October 2026: <https://developer.apple.com/download/files/CarPlay-Developer-Guide.pdf> (categories p. 4, guidelines, entitlements table: `com.apple.developer.carplay-video`, iOS 27; template table).
- WWDC26 session 212, "Rev up your CarPlay app": <https://developer.apple.com/videos/play/wwdc2026/212/>
- Apple Developer Forums thread 851377 (Audio and Video cannot be combined, iOS 27.2): <https://developer.apple.com/forums/thread/851377>
- CarPlay overview and request link: <https://developer.apple.com/carplay/>, <https://developer.apple.com/contact/carplay/>
- Refusal reasons reported by developers (secondhand): <https://newly.app/how-to/carplay-entitlement>, <https://www.hackingwithswift.com/forums/swiftui/notifications-and-carplay/23749>
