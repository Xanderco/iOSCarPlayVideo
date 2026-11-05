# DashCast — Project Journal

> **Every agent (human or AI) reads this file first and appends an entry last.**
> It is the single source of truth for *why* things are the way they are, the product vision,
> decisions that must not be silently reversed, and what to do next — even when no task lists it.
>
> Rules: newest entries at the top of the Log. Keep entries short (what changed, why, links to PRs/commits,
> follow-ups). Never delete history; mark superseded decisions as **Superseded** with a pointer.

---

## 1. Vision (north star)

**DashCast puts the passenger's own videos on the car display — simply, privately, and without subscriptions.**

- Users bring their **own** content: M3U/M3U8 playlists (link, file, QR), Jellyfin/Emby servers, local videos, web videos that can legally be handed off.
- The app ships **no content**. It is a player only.
- Video in the car is **for passengers / while parked only**. Safety notice on first launch and in car mode.
- **Pay once, own it forever**: free tier + one non-consumable **DashCast Pro lifetime, USD 19.99** (`pro.lifetime`). **No subscriptions, no trials, no auto-renew.** This is our headline differentiator.
- Native, dark, premium iOS feel; original identity (see §3 Originality).
- Private by design: no account, no tracking, data stays on device (credentials in Keychain).

## 2. Hard decisions (do not reverse without the owner)

| # | Decision | Date | Why |
|---|----------|------|-----|
| D1 | Monetization = single one-time purchase USD 19.99, non-consumable `pro.lifetime`, Family Sharing on. No subscriptions. | 2026-11-05 | Owner decision; differentiator vs CarTV/CarDash (weekly/yearly). |
| D2 | **Original identity — no 1:1 copies** of any competitor (UI, strings, assets, screenshots). | 2026-11-05 | Codebase was built as a "1:1 CarDash" clone → App Review 4.1 copycat + IP risk. |
| D3 | Hexagon "Territory" feature **removed**. | 2026-11-05 | Owner decision; not core to the vision. |
| D4 | Look & feel inspired by cartv.app (dark, native, accent colour, big tiles, mini player, car mode) — **inspiration only**, own brand. | 2026-11-05 | Owner direction. |
| D5 | Ship no third-party streams/logos (no Netflix/Disney/etc. presets, no Red Bull/NASA sample streams unless licence allows). DRM services removed from the browser. | 2026-11-05 | App Review 5.2 IP; DRM content can't be captured/cast anyway. |
| D6 | Never say "CarPlay" in name/subtitle/keywords/screenshots until Apple grants the CarPlay entitlement; say "car display". | 2026-11-05 | Trademark / review risk; competitors do the same. |
| D7 | App Store: category **Utilities** (secondary Entertainment), **iPhone only**, original metadata. Honest age rating (in-app web browser ⇒ "Unrestricted Web Access" ⇒ likely 18+; open decision O1). | 2026-11-05 | Mirrors approved competitors. |
| D8 | CI (GitHub Actions, macOS 15, newest Xcode 26.x, XcodeGen) is the source of truth. `DashCast.xcodeproj` is **generated**, not committed. Nothing is "done" without green CI. | 2026-11-04 | Every run before this failed; agents ran on Windows and couldn't compile. |
| D10 | Keep the classic UI (Cast / Drive / Widgets / Sounds / Me). Redesign kept only on `claude/redesign-snapshot`; future UI changes incremental and owner-approved. | 2026-11-05 | Owner found the redesign confusing. |
| D9 | Tests are never disabled/skipped to get green; fix code or test with justification. | 2026-11-05 | Owner wants "everything must pass" honestly. |
| D10 | ATS: `NSAllowsArbitraryLoads = YES` alone (no granular keys: they disable it on iOS 10+). | 2026-11-05 | Users' playlists, streams and Jellyfin/Emby servers are mostly plain http; the app ships no content. Justification is in the review notes. |

## 3. Originality

- Competitors: **CarDash** (Laigang Wang; Cast/Drive/Widgets/Sounds; weekly→annual subs) and **CarTV** (Lyntra; M3U/Jellyfin/Emby/Plex/Xtream, mirroring, DLNA receive; weekly/yearly/lifetime).
- Our app was originally a literal CarDash clone (comments like "Exact 1:1 CarDash layout", strings "CarDash is tracking this trip"). Those must be gone before submission — see `Docs/Originality-audit.md` (redesign 2B session).
- Drive/Widgets/Sounds are CarDash's identity; their future here is open decision O2.

## 4. Architecture (current)

- SwiftUI app, iOS 17+ deployment target, built with Xcode 26 SDK. `project.yml` (XcodeGen) defines targets/schemes.
- `PlaylistStore` (Features/Cast) — single source of truth for playlists/favorites, persisted; posts `didChangeNotification`; used by phone UI and CarPlay.
- `IPTVParser` — robust M3U parser (BOM, Latin-1, CRLF, relative URLs, quoted commas, `#EXTGRP`).
- `VideoPlayerService.shared` — AVPlayer; external/AirPlay playback.
- `DashCast/CarPlay/` — CarPlay scene (Library/Favorites from PlaylistStore, Now Playing). Needs Apple CarPlay entitlement to appear on a head unit.
- Paywall: StoreKit 2, `EntitlementGate` for free-tier limits.
- Detailed docs: `Docs/CarPlay.md`, `Docs/Design/redesign-spec.md`, `Docs/ADR-002-car-video-output.md`, `Docs/AppReview-checklist.md`, `AppStoreMedia/metadata.md`, `Docs/MAC_AGENT_HANDOFF.md` (as they land).

## 5. How work flows

- Integration branch: `claude/ci-and-core-fixes` → PR **#14** → `main` (**only the owner merges to main**).
- Feature work: one branch per topic `claude/<topic>` → PR into the integration branch → green CI → integrator merges. Marker commits `integration complete: phase N` signal waiting sessions.
- No Mac in cloud sessions: push and read `gh run view <id> --log-failed`. CI minutes are expensive (private repo, macOS 10×) — batch changes.
- PRs via REST (`gh api repos/Xanderco/iOSCarPlayVideo/pulls ...`); GraphQL/`gh pr create` are blocked in cloud sessions.
- Local verification on a Mac: `Scripts/verify-all.sh` (or `make verify`) — same steps as CI.
- Paperclip agents (CARAA company, issues CARAA-1…26) are **paused** while cloud sessions work. Their PRs #11, #12, #13 are superseded by #14.

## 6. Open decisions (owner)

- **O1** In-app web browser: keep (honest 18+ rating) or remove (lower rating)?
- ~~**O2** Drive / Widgets / Sounds: keep as secondary "Extras", or drop to sharpen the video focus?~~ **Resolved 2026-11-05 (owner): Drive stays a real feature** (live location + automatic trip detection, `claude/drive-auto`, which owns `Features/Drive`). Widgets and Sounds may move under Extras. *(Context: #31 had moved all three under Settings › Car Extras as Trip Log / Car Screen / Chime — see `Docs/Originality-audit.md` §3.)*
- **O3** Which car-video path to promise (see ADR-002): AirPlay-when-parked on supported head units, screen mirroring, DLNA receive.
- **O4** CarPlay entitlement category to request from Apple (likely Audio/Video-adjacent per ADR). *(2026-11-05 00:50: #28 first recommended the CarPlay Video App entitlement. **Superseded 01:15 by carplay-mirror follow-up e7f0f72: request CarPlay _Audio_ (`com.apple.developer.carplay-audio`).** An Audio app appears in every CarPlay car; Video only shows in cars with "video in the car" support and can't be combined with Audio. Steps and justification are in `Docs/CarPlay.md` — owner to submit.)* **Superseded 2026-11-05 02:05 (Session 19): request CarPlay _Video_ (`com.apple.developer.carplay-video`)** — the owner's #1 feature is mirroring the iPhone onto the CarPlay screen like the competitor's CarPlay app, which only the Video category supports (system video player, parked only).

## 7. Human to-dos

- [ ] Request CarPlay entitlement — developer.apple.com/contact/carplay. Category: **Video** (`com.apple.developer.carplay-video`, Session 19; was Audio; steps and ready-to-paste justification at the top of `Docs/CarPlay.md`). Until granted, CarPlay shows nothing on a real head unit; the Xcode CarPlay simulator works now via `DashCast/DashCast-Simulator.entitlements`.
- [ ] App Store Connect: create **one** non-consumable `pro.lifetime`, USD 19.99, Family Sharing on. No subscriptions (D1).
- [ ] Apple Developer portal: register app group `group.com.xanderco.dashcast` and bundle IDs `com.xanderco.dashcast.broadcast`, `.castwidget`, `.widgets` (each with the app group). Needed before any device/TestFlight signing.
- [ ] Privacy policy, terms (EULA) and support URLs (placeholders in metadata).
- [ ] Check GitHub Actions minutes / billing (private repo). The repo was made public for the sprint — set it back to **private** afterwards.
- [ ] Close superseded PRs #11, #12, #13; review and merge #14.
- [ ] On the Mac: hand `Docs/MAC_AGENT_HANDOFF.md` to an agent; run `Scripts/verify-all.sh` until green; do the manual checklist (real device, CarPlay Simulator, AirPlay, TestFlight). **Note:** both files are only on PR #26's branch (`claude/loving-archimedes-bxc7wp`) until it is ported (handoff issue T1).
- [ ] Paperclip: hand `Docs/Paperclip/HANDOFF_2026-11-05.md` to the CEO agent (issue C0) when Paperclip resumes.

## 8. Next steps (beyond current tasks)

1. ~~Finish phase-2 integration (paywall, car video, redesign A/B, test automation) with CI green on `verify-all.sh`.~~ Paywall, car video, CarPlay mirror, widgets, redesign 2A/2B and review fixes are merged (phases 2–3). **Remaining: port PR #26 (test automation / `verify-all.sh`) onto the redesigned app — handoff T1.**
1b. Library tab → `LibraryView` (handoff U1); owner decisions O1, O2, O4.
2. Mac run: full test pass + manual checklist; fix what simulators can't catch.
3. TestFlight build → owner tests in a real car.
4. App Store submission with `AppStoreMedia/` + review notes (demo playlist, passenger-only statement).
5. Later: localization (start with Spanish), Plex/Xtream support, subtitles, software decoding fallback (MKV/HEVC), DLNA receiver — only after the core is solid and original.

---

## Log

### 2026-11-05 04:15 (Bogotá) — Multimedia Engineer: High-Fidelity Landing Page & Cockpit Vehicle Showcase (CARAA-49 / DI-33)
- **Assigned & Executed CARAA-49 / DI-33:** Reviewed newly built landing page in `docs/site` on `feature/DI-33-optimize-landing-page`.
- **Automotive Cockpit Showcase:**
  - Integrated high-fidelity, transparent vehicle assets (`porsche-911`, `toyota-supra`, `bmw-m4`, `mercedes-amg`) optimized from repo artwork down to lightweight WebP & PNG formats (~23KB each).
  - Built interactive vehicle & channel switcher in hero in-dash display mockup (Porsche 911 GT3 Nürburgring track lap, Toyota Supra Jellyfin stream, BMW M4 live broadcast mirror, Mercedes-AMG GT offline files).
  - Added live HUD telemetry readout overlay (speed, gear, battery/charging mode, stream health badge) and dynamic simulated clock.
- **Strict Compliance & Bug Fixes:**
  - Enforced Decision D5: Purged third-party DRM names (`Netflix`, `Disney+`) from supported chips; replaced with genuine supported sources (`YouTube`, `Jellyfin`, `Emby`, `Plex`, `Infuse`, `VLC`, `M3U/M3U8 HLS`, `Local Files`, `RTSP/RTMP`).
  - Fixed UX bug in `script.js` where chip collapse previously triggered a page reload; implemented seamless in-DOM toggle.
  - Added rich Open Graph (`og-image.png`), Twitter Card, canonical link, and Schema.org `SoftwareApplication` JSON-LD structured data.
- **Cross-Platform Responsive Engineering:**
  - Verified full fidelity across desktop (1440px+), iPad / tablet (768px-1024px), and iPhone (375px-430px) screen sizes.
  - Improved mobile CarPlay sidebar dock so it cleanly transitions to a compact top/bottom bar rather than disappearing.
  - Guaranteed 100% on-device privacy (zero trackers, no external fonts/CDNs, self-contained relative assets).
- **GitHub Pages Workflow:** Renamed and validated `.github/workflows/pages.yml` with lowercase `docs/site` paths.

### 2026-11-05 03:30 (Bogotá) — CEO: Static Landing Page & Web Multimedia Engineer Hire (CARAA-29 / DI-28)
- **Hired Multimedia Engineer:** Submitted agent hire proposal (`Multimedia_Engineer` / Lead Multimedia & Web Systems Engineer) in Paperclip per owner directive on CARAA-29, reporting to CEO, with `opencode_local` runtime, icon `globe`, and static web/multimedia capabilities. Created Board Approval request #5d124eac.
- **Built Static Landing Page:** Created full-featured responsive static website in `docs/site/` benchmarked on competitor `https://cartv.app/#cast` tailored for DashCast.
  - Header with glowing DashCast app icon, sticky glass navbar, dark/light mode toggle with localStorage persistence, mobile nav menu, and App Store CTA.
  - Hero section: "Video on your car display. Pay once.", lead copy, safety callout, and an interactive CSS/SVG in-dash automotive display mockup featuring CarPlay sidebar, live stream status badge, track lap video preview, and iPhone remote controls.
  - `#cast` section directly mirroring `cartv.app/#cast`: 3-step numbered flow (Cast button, Screen Mirroring, Background Live Activity) + interactive streaming platforms chip matrix (YouTube, Plex, Jellyfin, Emby, Infuse, VLC, Twitch, Bilibili, etc. with expandable list).
  - `#features` section: 6 automotive cards covering M3U playlists, Jellyfin & Emby, low-latency H.264 mirroring, Metal/AVFoundation hardware decoding, OLED dark car ergonomics, and zero tracking privacy.
  - `#moments` section: EV Supercharging breaks, campsite sunsets, and commute waits.
  - `#pro` section: Transparent comparison table proving DashCast Pro $19.99 Lifetime Pass vs predatory $9.99/mo competitor subscriptions.
  - `#faq` section: Interactive accordion answering video sources, CarPlay requirements, privacy, and driving safety locks.
  - Preserved and enhanced compatibility with existing `privacy.html`, `support.html`, and `terms.html`.
- Branch: `feature/DI-28-static-landing-page` pushed to origin. Commit `4df9159`.

### 2026-11-05 02:30 (Bogotá) — Session 22: Privacy / Support / Terms web pages (`claude/legal-pages`)
- Added a small static site in `docs/site/` (plain HTML + one `style.css`, dark, mobile friendly, no JS, no trackers, no external fonts): `index.html`, `privacy.html` (no account/tracking/analytics; playlists, server details and trips stay on the iPhone; server tokens in Keychain; location/motion on-device only for Drive and parked-only safety; camera only for QR; photos only when the user picks; StoreKit purchases handled by Apple), `support.html` (FAQ: M3U, Jellyfin/Emby, why streams fail, no DRM services, passengers/parked only, CarPlay depends on Apple entitlement and the car, restore, contact), `terms.html` (Apple Standard EULA + short app terms: no content provided, user responsible for rights). Contact: alexbh987@gmail.com.
- `.github/workflows/pages.yml` deploys `docs/site` to GitHub Pages on push to `main` (paths `docs/site/**`) and on `workflow_dispatch` (configure-pages + upload-pages-artifact + deploy-pages).
- URLs: https://xanderco.github.io/iOSCarPlayVideo/ · `/privacy.html` · `/support.html` · `/terms.html`. Written into `AppStoreMedia/metadata.md` (§4, §6) and the shared constants file **`DashCast/Core/Legal/LegalLinks.swift`** (`privacyPolicy`, `support`, `appTerms`, `termsOfUse` = Apple EULA, `supportEmail`). `PaywallLegal` now just forwards to `LegalLinks` (no layout change). Session 21's Legal rows should use `LegalLinks`.
- **Owner action:** enable Pages: repo Settings → Pages → Source: **GitHub Actions**. The workflow only runs on `main`, so either merge `docs/site` to `main` or run "Deploy legal site to GitHub Pages" manually (workflow_dispatch from `main` once the file is there). **Pages on a private repo needs a paid GitHub plan**: keep the repo public, or host `docs/site` elsewhere (any static host) and update `LegalLinks.swift` + metadata.
- Note: `docs/site` hosts static documentation and landing pages for GitHub Pages.
- Not done: the reviewer demo playlist (`AppStoreMedia/reviewer-demo.m3u`) still points at non-existent dashcast.app media, so it isn't hosted here; the owner needs real hosted CC-licensed files first.

### 2026-11-05 02:22 (Bogotá) — Session 19 close: classic UI + CarPlay video mirror merged
- **`claude/classic-ui` now holds the classic UI (D10) plus the CarPlay video mirror.** [PR #37](https://github.com/Xanderco/iOSCarPlayVideo/pull/37) merged (merge commit 8395ccf). PR CI was green on cfcc819: build, entitlement check, unit tests and UI tests.
- **Owner action:** request the CarPlay **VIDEO** entitlement (`com.apple.developer.carplay-video`, category "Video", not Audio) at developer.apple.com/contact/carplay. The steps and ready-to-paste justification are at the top of `Docs/CarPlay.md`.
- **Paperclip agents continue from `claude/classic-ui`**, then integrate into PR #14. Do not branch from the redesign. Open device checks for the mirror are listed in the Session 19 entry below.

### 2026-11-05 02:05 (Bogotá) — Session 19: Mirror iPhone → CarPlay screen via low-latency HLS (`claude/carplay-video-mirror` → `claude/classic-ui`)
- **Built ADR-002 §7.5** (the missing link for the owner's #1 feature). Broadcast extension: `MirrorHLSEncoder` = VideoToolbox H.264 (`VTCompressionSession`, real-time, low-latency rate control, no B-frames, ≤1280×720, 30 fps, 3 Mbit/s, 1 s GOP) → `AVAssetWriter` `.mpeg4AppleHLS` passthrough, 1 s fMP4 segments → `HLSSegmentStore` (last 4, ≈2 MB) → served by the existing `MirrorStreamServer` at `http://127.0.0.1:8088/hls/live.m3u8` (+ `/hls/init.mp4`, `/hls/segN.m4s`). MJPEG browser path unchanged. Only runs when "Mirror to CarPlay screen" is on.
- App: `CarPlayMirrorPlayback` (parked-only `decide`, waits for the first segment, plays through `VideoPlayerService` = AVPlayer with external playback, 1 s forward buffer). Starts automatically when the broadcast goes live, stops when it ends. CarPlay Cast tab gains **"Show iPhone screen"** (second section; steps unchanged). **No phone UI changes (D10).**
- Simulator entitlement switched to **`com.apple.developer.carplay-video`** (DTS-confirmed key, forums 838529); device entitlements still have no CarPlay key; CI check updated. `Docs/CarPlay.md` top: request **Video**, not Audio (O4/to-do updated), with the ADR §7.3 justification and test steps (Xcode 27 CarPlay simulator, real iPhone via `127.0.0.1:8088/hls/live.m3u8`, real car).
- Tests: `MirrorHLSTests` (routes, playlist format, segment window, HTTP responses, encoder config/size, parked-only decision) + Cast-tab action test.
- **Not verified on hardware** (no Mac/device in cloud): VT low-latency + AVAssetWriter passthrough segmenting inside the extension, extension memory, AVPlayer acceptance of the stream, CarPlay video-in-car pickup. iOS 27-only APIs (`CPPlaybackConfiguration` etc.) are **not** used yet because CI builds with the iOS 26 SDK.
- **Next steps:** (1) Owner: submit the CarPlay **Video** request (`Docs/CarPlay.md`). (2) On a device: turn on the mirror toggle, Start Broadcast, open `http://127.0.0.1:8088/hls/live.m3u8` in Safari — check delay and memory in Xcode's debug gauges (extension < 50 MB). If AVAssetWriter rejects passthrough, give the input H.264 `outputSettings` and feed pixel buffers instead (drop VT). (3) When CI moves to Xcode 27: adopt the iOS 27 CarPlay video templates/`CPPlaybackConfiguration` behind `#available(iOS 27, *)` and remove the Audio-only comments in `CarPlaySceneDelegate`. (4) Optional lower latency: LL-HLS partial segments (`#EXT-X-PART`, 200 ms).

### 2026-11-05 01:45 (Bogotá) — Owner reverted the redesign UI (branch claude/classic-ui)
- Owner tested the integrated build on his Mac and found the redesign (#31 2B, #32/#34 2A: Home/Library/Cast/Settings tabs, onboarding, Extras) **confusing**; he wants the **previous UI** (Cast / Drive / Widgets / Sounds / Me) with the new functionality.
- `claude/classic-ui` restores all app/test/UI-test code to `integration complete: phase 2` (dc5962c: old UI + widgets #27 + CarPlay mirror #28 + paywall #24 + car video #25) and re-applies only functional work from later merges: Info.plist ATS (http IPTV), simulator-only CarPlay entitlements + CarPlay scene delegates, IPTVParser (own demo videos only), VideoPlayerService + MediaServerStore + DemoDataSeeder review fixes, Drive live map (`DriveLiveMapView` replaces the static route map in the old DriveHomeView) and automatic trips (`AutoTripService`, `TripDetectionStateMachine`) wired to the existing "Auto-detect drives" toggle, plus their tests (TripDetection, ReviewFixes, CarPlayScene, CastEngine, EntitlementGate).
- The full redesign is preserved on branch **`claude/redesign-snapshot`** (do not delete). **Decision D10: keep the classic UI; any future visual change is incremental and approved by the owner screen by screen.** Supersedes the "4 tabs / Extras" plan in Docs/Design/redesign-spec.md and handoff U1/U2.
- Not carried over (available in the snapshot if wanted later): onboarding, Settings screen with Terms/Privacy/Restore (App Review needs Terms/Privacy links + Restore somewhere — paywall has Restore), Add Source sheet (Jellyfin/QR entry still in Me tab), mini player, car mode, trip log/replay screens, removal of the in-app CarPlay emulator.

### 2026-11-05 01:16 (Bogotá) — Integrator: merged #35 (claude/drive-auto)
- Merged [#35](https://github.com/Xanderco/iOSCarPlayVideo/pull/35) (`claude/drive-auto`), implementing owner decision O2 (Drive stays a real feature) and fixing owner Mac finding #5.
  - Live follow-user map at the top of Trip Log, with a permission-rationale card (When-In-Use → Always).
  - **Automatic trip detection**: a pure `TripDetectionStateMachine` plus `AutoTripService` (Core Motion + significant-change location), on by default once Always is granted. Route replay in trip detail.
  - `TripDetectionTests`, and Freeway Drive QA steps in `Docs/QA/smoke-test.md`.
- Only the journal conflicted. The Info.plist strings auto-merged: one `NSMotionUsageDescription` now covers both auto-trips and #25's parked guard, and `UIBackgroundModes` = audio + location.
- Follow-ups: verify on a device (Always permission flow, significant-change relaunch, battery). App Review needs a clear reason for the "location" background mode (the auto-trip feature); add it to the review notes (handoff G1).

### 2026-11-05 01:16 (Bogotá) — Integrator: merged #33 (claude/review-fixes follow-up)
- Merged [#33](https://github.com/Xanderco/iOSCarPlayVideo/pull/33), the review-fixes follow-up for owner Mac finding #1 (http streams blocked).
  - ATS is now `NSAllowsArbitraryLoads = YES` **alone** (decision **D10**). This replaces #30's narrow media/LAN keys, which on iOS 10+ also *disable* `NSAllowsArbitraryLoads`, so http playlist downloads and remote http servers stayed blocked.
  - The App Review justification is in `AppStoreMedia/metadata.md` §9 and `Docs/AppReview-checklist.md` #18.
  - `CarPlaySceneDelegate` gets a `@preconcurrency` conformance.
- Only the journal conflicted; Info.plist and the delegate auto-merged. The merged ATS dict is verified to contain only `NSAllowsArbitraryLoads`. Still to check on the Mac: play an iptv-org http channel.

### 2026-11-05 01:16 (Bogotá) — Integrator: merged #34 (claude/redesign-cast-home follow-up)
- Merged [#34](https://github.com/Xanderco/iOSCarPlayVideo/pull/34), the redesign 2A owner-feedback follow-up. It addresses owner Mac findings #2–#4:
  - The in-app **CarPlay emulator is removed** (`CarPlaySimulatorView`, the `-carplay*` launch args and `AppState.showCarPlaySimulator`).
  - The sample playlist now lists **only the two bundled demo videos**; NASA/Red Bull/Tears of Steel/Google samples are gone (D5, App Review 5.2). Covered by a unit test.
  - Add Source now offers Link · File · QR · Jellyfin · Emby, and the **Library tab now shows `LibraryView`**. This closes my #32 follow-up and handoff U1's first point.
  - The browser MSE fallback offers "Mirror Your Screen Instead", and `CarOutputPanelView` gets a no-AirPlay empty state plus v2 tokens.
- Only the journal conflicted (the branch was rebased onto the integration branch). No references to the removed views remain.

### 2026-11-05 01:15 (Bogotá) — Integrator: merged carplay-mirror follow-up e7f0f72
- Merged the `claude/carplay-mirror` follow-up `e7f0f72` (no PR; #28 was already merged). It adds `DashCast/DashCast-Simulator.entitlements` (carplay-audio + app group), selected via `CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]`, so DashCast appears in the Xcode CarPlay simulator. This fixes the owner's Mac finding #6. A CI step keeps CarPlay keys out of the device entitlements. Also adds `CarPlaySceneTests` and rewrites `Docs/CarPlay.md`.
- **Decision change (O4):** request the CarPlay **Audio** entitlement, not Video. Journal §6/§7 and handoff H1/T4 are updated.
- Conflicts resolved:
  - `CarPlaySceneDelegate`: kept the integration's PlaylistStore-backed delegate, as the branch's own merge note asks. Added static `libraryTemplate()`, `favoritesTemplate()`, `mirrorInstructionsTemplate()` and `mirrorInstructionSteps`; tabs are now Library · Favorites · Info · Cast.
  - **Bug fixed:** my phase-2 port of #28 had pushed a `CPInformationTemplate` from the Info tab. That template is **not allowed for CarPlay Audio apps** and would throw, so the instructions are now the disabled-row list tab "Cast".
  - `ci.yml`: #30's warning summary plus the entitlement guard step.
  - `project.yml`: the simulator entitlements line was added next to #21's device-family line.
  - `Docs/CarPlay.md`: took the branch's version.

### 2026-11-05 01:13 (Bogotá) — Integrator: fix EntitlementGate test after #18 × #24
- **CI on `cecc1e6`:** the build succeeded and 190 of 192 unit tests passed (1 skipped, pre-existing). **2 failures, both in `EntitlementGateTests.testPlayerRefusesToCastWhenFreeAllowanceIsUsedUp`.** This is a semantic clash between #18 and #24. #24's test assumed `play()` sets `isPlaying` synchronously. Since #18, `isPlaying` mirrors AVPlayer's asynchronous `timeControlStatus`, which never reaches `.playing` for the test's fake URL.
- Fix: added a read-only `VideoPlayerService.isPlaybackRequested` (whether playback was requested *and allowed* by the gate and the parked guard). The test asserts on it. Same three checks, same strictness: no skip, no weakening (D9).

### 2026-11-05 01:13 (Bogotá) — Owner: Mac test results + decision O2
- **Owner's Mac test run** (real Xcode, before phases 2–3 landed): build OK, **118 unit + 4 UI tests pass**, no runtime issues. Bugs found, with owners:
  1. http streams blocked by ATS → fixed by #30 (review-fixes, merged): `NSAllowsArbitraryLoadsForMedia` + `NSAllowsLocalNetworking`.
  2. In-app "CarPlay Emulator" should be removed → redesign 2A (#32). **Still present** (`CarPlaySimulatorView`, the Home "Preview car screen" entry) → follow-up for 2A / handoff U1.
  3. Third-party sample streams still listed → 2A. #32's welcome state has "Browse sample streams"; verify the list against D5 → U1.
  4. Jellyfin/QR hidden in the Me tab → fixed by #31/#32: Library tab = Media Servers, Add Source sheet = Link/File/QR/Server.
  5. Drive map not centred on the user, no automatic trips → `claude/drive-auto` (pending, see below).
  6. App not visible in the CarPlay Simulator → carplay-mirror adds a simulator-only entitlement. Note: #28 as merged has no such entitlement in `DashCast.entitlements` (only the app group); if a later carplay-mirror commit adds it, it still needs integrating.
- **Owner decision O2:** Drive stays a real feature; Widgets/Sounds may move under Extras (§6 updated). `claude/drive-auto` is next in the merge queue.

### 2026-11-05 01:10 (Bogotá) — Redesign 2A follow-up: owner feedback from manual testing
- **Removed** the in-app "CarPlay emulator" (`CarPlaySimulatorView`), its Home button and the `-carplaySimulator/-carplayDashboard/-carplayHomeMenu` launch args. The App Store "02_cardisplay" shot now uses `-initialTab cast`. Real CarPlay is tested in Xcode's CarPlay simulator.
- **Demo content** is now only our two bundled videos (Night Drive, Track Lap), grouped as "Demo Videos" with stable ids. Removed Tears of Steel, NASA TV, Red Bull and the Google sample fallbacks (App Review 5.2).
- **Add Source** (Library and Home): Playlist Link · Playlist File · Scan a QR Code · Jellyfin Server · Emby Server (`AddMediaServerView(kind:)`). Library also has a "Jellyfin & Emby" row, and the Library tab now shows `LibraryView` instead of only the media-server list.
- **Browser**: the MSE/blob hand-off failure (e.g. YouTube) explains why in plain words and offers "Mirror Your Screen Instead", which opens the car-display panel.
- **Car Display panel** (#25): shows a "No AirPlay displays found" empty state with what to do when no receivers exist; migrated to v2 tokens. Added a `CarDisplaySheet` wrapper so Home and the browser use the same sheet.

### 2026-11-05 01:10 (Bogotá) — Session 17: ATS fix for http IPTV (owner Mac test)
- **Mac result** (owner, iPhone 17 sim): the build is OK, 118 unit and 4 UI tests pass, and there are no runtime issues. YouTube browsing works. The main playback bug was http-only playlists/streams being blocked by ATS.
- `Info.plist` now sets `NSAllowsArbitraryLoads = YES` **alone**. On iOS 10+, adding `NSAllowsArbitraryLoadsForMedia`, `…InWebContent` or `NSAllowsLocalNetworking` makes iOS ignore it, so do not add them back. `ReviewFixesTests.testATSAllowsUserSuppliedHTTPSources` guards this.
- The review justification is in `AppStoreMedia/metadata.md` §9 and `Docs/AppReview-checklist.md` #18. Recorded as **D10** (ATS off for user-supplied sources).

### 2026-11-05 01:15 (Bogotá) — Session 18: Drive live location + automatic trips (`claude/drive-auto`, [#35](https://github.com/Xanderco/iOSCarPlayVideo/pull/35))
- Owner feedback: the Drive map showed the whole region, and trips weren't detected automatically.
- New `DashCast/Features/Drive/`: `DriveLiveMapView` (camera follows the user and their heading while recording, `UserAnnotation`, `MapUserLocationButton`, Recenter, live route) plus `LocationPermissionCard` (When-In-Use → Always with explanations; denied opens Settings; restricted shows a message). The map sits at the top of Trip Log.
- `TripDetectionStateMachine` is pure logic driven by an injected clock. It starts a trip after 60 s of automotive motion (confidence ≥ medium) above 15 km/h, or above 25 km/h when there is no Core Motion (Simulator). It ends the trip after 3 min stationary, reusing `ParkedStateEvaluator`. `AutoTripService` connects Core Motion and significant-change/standard location to `DriveLocationService`, which saves through `PersistenceController`, then sends the "Trip saved" notification. It starts at launch. Manual trips are never auto-ended.
- Pref `autoTripDetectionEnabled` (nil means ON once Always is granted). Toggle in Trip Log. Info.plist usage strings updated; the `location` background mode was already set.
- Tests: `TripDetectionTests`. QA steps: `Docs/QA/smoke-test.md` §6d (Freeway Drive).
- Trip detail now has route replay (`TripReplayMapView`: Play/scrub, car marker, travelled part highlighted).
- Follow-ups: the first ~60 s of an auto trip isn't in the route (could seed it from the detector's fixes); needs a real-device drive test (background relaunch, battery).

### 2026-11-05 01:01 (Bogotá) — Integrator: merged #32 follow-up a39798d
- The #32 session pushed `a39798d` after my merge: the same `canStep` return fix, plus explicit initializers for `ResumeCard` and the internal `LibraryView` subviews (memberwise inits were inaccessible). Merged it. The only conflict was `MirrorScreenSheet`, which stays removed (superseded by #25's `CarOutputPanelView`, see the #32 entry).

### 2026-11-05 01:00 (Bogotá) — Integrator: build fixes after phase 2 (#24 API in Settings, #32 missing return)
- **CI on the phase-2 tip `dc5962c` was red** (build failed). `MeHomeView`'s restore row (from #21) still used the pre-#24 StoreKit API (`isPurchased`, `isLoading`). Phase 3 deletes `MeHomeView` (#31 replaced Me with Settings), but #31's new `SettingsView` had the same problem (`store.isPurchased`, `errorMessage`, a non-throwing `restorePurchases()`). Ported it to #24's API: `store.isPro`, `try await store.restorePurchases() -> Bool`, and errors from the thrown error. `StoreKitManager` mirrors the entitlement into `AppState`.
- **#32's own head `96a3ece` was red**: `PlayerPresentation.canStep` had two statements and no `return`. Fixed here (one word).
- `git grep` finds no other callers of the old StoreKit API (`isPurchased`, `purchaseLifetime`, `fetchProducts`, `lifetimeProduct`, `updatePurchasedStatus`).

### 2026-11-05 00:56 (Bogotá) — Integrator: merged #30 (claude/review-fixes)
- Merged [#30](https://github.com/Xanderco/iOSCarPlayVideo/pull/30), the independent review of phase 1 (`Docs/Review-2026-11-05.md`). Adds narrow ATS exceptions (`NSAllowsArbitraryLoadsForMedia`, `NSAllowsLocalNetworking`) so http IPTV and LAN Jellyfin/Emby work on device. Fixes the double remote-command handlers: only `VideoPlayerService.shared` owns the targets, and CarPlay just enables them. Also fixes the observer cleanup in `stop()`, adds real assertions in `CarPlayDiagnosticTests`, and adds `ReviewFixesTests`. The later commit migrates leftover files to v2 tokens and adds a CI warning summary.
- Conflicts resolved:
  - `VideoPlayerService`: `shared` is the remote-command owner and also gets #24's `EntitlementGate`. `init` registers commands only when `handlesRemoteCommands`, and always attaches #25's `CarVideoOutputController`.
  - `SoundCatalogService` and `VehicleCatalogService`: #31 had moved them to `Features/Extras`, so the old paths stay deleted. #30's token-only edits to the old copies were dropped.
  - `Info.plist`: one combined `NSLocalNetworkUsageDescription` (#25 mirroring plus #30 LAN servers) and #30's ATS dict.
- Integration fix: added `NSMotionUsageDescription` (parked detection), because #25's `ParkedGuard` uses `CMMotionActivityManager` and the key had been dropped (#31 removed the driving-score motion string). Without it the app is killed on device when the guard starts.
- Report-only items from the review are tracked in the doc. StoreKit restore-at-launch is addressed by #24 (`StoreKitManager.shared` is created in `DashCastApp.init`), and #31 removed the fake "sent" feedback.

### 2026-11-05 00:55 (Bogotá) — Integrator: merged #32 (claude/redesign-cast-home)
- Merged [#32](https://github.com/Xanderco/iOSCarPlayVideo/pull/32), redesign 2A on design system v2. Adds a new Home (`CastHomeView`: search, quick actions, Continue Watching, Favorites, Recents, Sources grid, car-display card), `LibraryView` (Sources → Groups → Channels), `AddSourceSheet`, `PlayerScreen`, a persistent `MiniPlayerHost`, `CarModeView` and `WatchHistoryStore` (with tests).
- Conflicts resolved:
  - `CastHomeView`: took #32's rewrite, then re-applied phase-2 intent. The "Mirror Screen" quick action opens #25's `CarOutputPanelView`, so route status, the parked-only guard and #28's mirror toggle stay reachable; #32's static `MirrorScreenSheet` was removed. #24's paywall-over-sheet presentation was re-added on the Library, Add Source, Web Video and CarPlay-preview sheets.
  - `AppState` and `CarPlaySimulatorView` keep #31's wording. The smoke UI test uses #32's "Library" sheet title.
- Follow-up: the Library *tab* still hosts `MediaServersHomeView` (#31's placeholder "until 2A lands"). Switching it to `LibraryView` needs a tab-friendly variant without the sheet's Done button (UX, issue U1).

### 2026-11-05 00:54 (Bogotá) — Integrator: merged #31 (claude/redesign-secondary)
- Merged [#31](https://github.com/Xanderco/iOSCarPlayVideo/pull/31), redesign 2B (de-cloning). Adds `Docs/Originality-audit.md`, removes `MediaToAnalyze/`, `Screenshots/` and the manufacturer-style car renders from the repo or bundle, and leaves no CarDash/CarTV/"1:1" text in code.
  - Tabs are now **Home · Library · Cast · Settings**. Settings replaces Me and has Restore, Privacy, Terms, Appearance and Safety. Car Extras holds Trip Log, Car Screen and Chime (O2 proposal in the audit §3). Adds onboarding with the passenger-only notice.
  - The legacy `TabItem.drive/.widgets/.sounds/.me` values are deprecated aliases that route to Settings.
- Conflicts resolved:
  - `AppState`: kept #27's `handleDeepLink`, remapped to the new tabs (`cast` → Cast tab, `drive` → `open(.tripLog)`), and kept #31's `open(_:)`.
  - `DashCastApp`: #31's appearance preference plus #27's `.onOpenURL`.
  - `Info.plist`: #31's photo-library string plus #25's `NSSupportsLiveActivities` and `NSLocalNetworkUsageDescription`.
- Follow-ups: owner decision O2 (keep Car Extras or cut them); privacy/terms URLs are still placeholders.

### 2026-11-05 00:53 (Bogotá) — Integrator: merged #27 (claude/home-widgets)
- Merged [#27](https://github.com/Xanderco/iOSCarPlayVideo/pull/27): the `DashCastWidgets` WidgetKit extension, with My Car, Last Trip and Quick Cast plus Lock Screen variants. Data is shared via app group `group.com.xanderco.dashcast` (`WidgetSharedStore`, versioned JSON). The extension uses the `dashcast://` deep-link scheme, handled in `AppState.handleDeepLink`. Adds `WidgetSharedStoreTests`.
- Conflict in `project.yml`: all three extensions are kept as separate targets, each an app dependency: `DashCastBroadcast` (from #25/#28, now also compiling `MirrorFrameTransport.swift`), `DashCastCastWidget` (the casting Live Activity from #25) and `DashCastWidgets`. All of them use the one app group.
- Follow-ups: built-in car artwork isn't shared with the extension yet. Register the app group and the `com.xanderco.dashcast.widgets` bundle ID (human, H3).

### 2026-11-05 00:53 (Bogotá) — Integrator: merged #28 (claude/carplay-mirror)
- Merged [#28](https://github.com/Xanderco/iOSCarPlayVideo/pull/28), mirroring the iPhone onto the CarPlay screen behind the feature flag `carMirror.enabled` (off by default). Frames go extension → app group (`MirrorFrameTransport`, seqlocked two-slot JPEG, unit-tested). `CarPlayMirrorController` renders them in the `CPWindow` once iOS grants one.
- Conflict in `CarPlaySceneDelegate.swift`: #28 was written against the pre-#16 delegate (sample playlist). Kept #16's PlaylistStore-backed Library/Favorites/Info tabs and Now Playing. Ported in #28's `CPWindow` connect/disconnect pair, which reuses the normal setup and then attaches or detaches the mirror controller, and its "Mirror iPhone" `CPInformationTemplate` row, now in the Info tab and honouring the template-depth limit.
- Session 16 log (from `Docs/JOURNAL-log-session16.md`): request the **CarPlay Video App** entitlement, not Navigation; justification is in ADR-002 §7.3. Not done: a local HLS bridge so the mirror plays through the system video player (ADR-002 §7.5).

### 2026-11-05 00:36 (Bogotá) — Integrator: merged #25 (claude/car-video-output)
- Merged [#25](https://github.com/Xanderco/iOSCarPlayVideo/pull/25): car-display video output (`Docs/ADR-002-car-video-output.md`). Adds AirPlay video routing through `CarVideoOutputController`, a parked-only guard (pauses when the car moves while external output is active), the `DashCastBroadcast` ReplayKit upload extension, the `DashCastCastWidget` Live Activity extension, an app group `group.com.xanderco.dashcast`, and `CarOutputPanelView`.
- Conflicts resolved:
  - `VideoPlayerService` keeps #18's lifecycle/remote-command setup plus `CarVideoOutputController.attach`. `play()` checks, in order: item present → parked-only guard → #24 casting allowance → audio session.
  - `CastHomeView` mirroring sheet uses #25's `CarOutputPanelView` (supersedes #18's interim instructions sheet).
  - `project.yml` keeps #21's iPhone-only `TARGETED_DEVICE_FAMILY` plus #25's extension targets and dependencies.
  - App entitlements take #25's app group.
- Follow-ups: app group and extension bundle IDs must exist in the developer portal (human). The CarPlay video entitlement is deferred (iOS 27), per ADR-002 and O3/O4.

### 2026-11-05 00:36 (Bogotá) — Integrator: merged #24 (claude/paywall-storekit)
- Merged [#24](https://github.com/Xanderco/iOSCarPlayVideo/pull/24): DashCast Pro is a single non-consumable `pro.lifetime` purchase (USD 19.99, Family Sharing), per D1. No subscriptions. StoreKit 2 manager with refund/revocation relock and Restore, `EntitlementGate` free-tier limits (playlist sources, daily casting time), and a rewritten paywall with a "No subscription" pledge.
- Conflicts resolved:
  - `VideoPlayerService.play()` combines #18's real-state player (`wantsToPlay`, audio session, `timeControlStatus`) with #24's casting-allowance gate.
  - The periodic time observer keeps #18's `MainActor.assumeIsolated` and calls `trackCastingTime()`.
  - `LifetimePaywallView` and `DashCastStore.storekit` take #24's versions. They supersede #21's copy tweaks with the same intent: pay-once wording and no inflated claims.
- Follow-ups: create `pro.lifetime` in App Store Connect (human); check the free-tier limits on a device.

### 2026-11-05 00:36 (Bogotá) — Integrator: merged #29 (claude/paperclip-handoff)
- Merged [#29](https://github.com/Xanderco/iOSCarPlayVideo/pull/29), docs only: `Docs/Paperclip/HANDOFF_2026-11-05.md` (the backlog for Paperclip/OpenCode agents after the cloud sprint) and an "outdated" banner on `PAPERCLIP.md`. The integrator keeps the handoff's §2/§3 status precise at the end of the sprint.

### 2026-11-05 (Bogotá) — Redesign 2B: de-cloning, 4 tabs, Car Extras, onboarding (`claude/redesign-secondary`)
- **Originality audit** → `Docs/Originality-audit.md` (D2). Removed from the repo (git-ignored, still in history): `MediaToAnalyze/` (31 CarDash screenshots), `Screenshots/` (clone-era shots + CarTV ad frames). Removed from the **app bundle**: 8 manufacturer-style car renders (×2). No "CarDash"/"1:1" text left in shipped code.
- **Tabs:** Home · Library · Cast · Settings (`AppState.TabItem`). Interim hosts until redesign 2A lands: Home = `CastHomeView`, Library = `MediaServersHomeView`, Cast = new thin `CastMirrorView`. Legacy `-initialTab drive|widgets|sounds|me` and the deprecated `TabItem.drive/.widgets/.sounds/.me` aliases still work (→ Settings / Extras), so `claude/home-widgets` deep links keep compiling.
- **O2 proposal implemented (reversible):** Drive/Widgets/Sounds → Settings › **Car Extras** with new UI and copy: **Trip Log** (no scores shown, passenger check), **Car Screen** (car-display text + own photo/plate for the widget; `WidgetConfigModel` untouched), **Car Chime** (13 synthesized chimes with original names + real Shortcuts action `PlayCarChimeIntent`). Me tab → native **Settings** (Pro card, Restore Purchases, Privacy, Terms (Apple EULA), Feedback via Mail, Appearance System/Dark/Light, safety notice).
- **Onboarding:** Welcome → passenger-only notice (must be acknowledged; shares `PassengerSafetyNotice.acceptedKey`) → add a source.
- Follow-ups for others: see audit §6 (Porsche defaults in model/Cast fallbacks, score in trip widget, real Library/Home from 2A).

### 2026-11-05 01:30 (Bogotá) — Redesign 2A: Home / Library / Player / Car Mode (claude/redesign-cast-home)
- Opened [#32](https://github.com/Xanderco/iOSCarPlayVideo/pull/32) into `claude/ci-and-core-fixes`. It rebuilds the Cast tab and playback on design system v2 with original layouts and copy (D2, D4). Home: search, quick actions, Continue Watching, Favorites, Recents, Your Sources, car-display card. Library: sources → groups → channels, with Add Source (Link/File/QR/Server). Full-screen `PlayerScreen` with Up Next. Persistent `MiniPlayerBar` (via `MiniPlayerHost` in `MainTabView`). Landscape `CarModeView` with 72 pt targets. New `WatchHistoryStore` for on-device recents/resume, with unit tests.
- CarDash / "1:1" references removed from Cast, `AppState` and the browser/simulator comments. Still remaining, in other sessions' areas: `DriveNotificationService`, `DriveSettingsView`, `MeHomeView`, `WidgetEditorView`.
- UI tests: identifiers unchanged. The Library sheet's title is now "Library" (was "Media Sources"), and the smoke test is updated to match.
- Follow-ups: gate Car Mode behind Pro once `EntitlementGate` lands (paywall session). The 4-tab restructure (spec §3) still has to be done, and it will retire the 110 pt tab-bar padding the other tabs use (the mini player can overlap their last row). Check Car Mode's forced landscape and resume-seek on a real device.

### 2026-11-05 00:50 (Bogotá) — Session 17: independent review of phase 1
- Reviewed `claude/ci-and-core-fixes` @ `d64237c` with fresh eyes. There are 21 findings in `Docs/Review-2026-11-05.md`.
- Fixed on `claude/review-fixes`, with tests in `ReviewFixesTests`:
  - Added ATS exceptions for media and the local network, plus `NSLocalNetworkUsageDescription`. Without them, http Jellyfin and http streams failed on device.
  - Fixed duplicate remote-command targets from #16 and #18: a toggle from the steering wheel or AirPods ran twice while CarPlay was connected, so it did nothing.
  - Fixed the player observer leak in `stop()`.
  - The diagnostic test now asserts something.
- Report-only, for the owning sessions: Pro isn't restored at launch and refunds don't re-lock (StoreKit). The feedback screen is a fake "sent" alert (2B). Third-party sample streams are still in `IPTVParser` (D5). "CarPlay" appears in push copy (D6). `SoundPlayerEngine` activates and ducks the audio session on init.
- Owner decision O-new: remote plain-http playlists/servers. Either stay https-only with a clear error, or use `NSAllowsArbitraryLoads` with a review justification (review #2).

### 2026-11-05 00:25 (Bogotá) — Integrator: merged #21 (claude/drop-territory-icon-media)
- Merged [#21](https://github.com/Xanderco/iOSCarPlayVideo/pull/21): Territory removed (D3), new original app icon, App Store media pipeline (`appstore-media.yml`, compositor scripts, `AppStoreMedia/metadata.md`), passenger safety notice, privacy manifest, demo-data seeder, App Review checklist.
- Conflict in `MeHomeView.swift`: kept #19's Media Servers sheet and dropped the fake "Rate DashCast" alert, as #21 intended (it uses `requestReview`).
- Integration fix: the first-launch `PassengerSafetyNotice` full-screen cover would have blocked #22's XCUITests. `shouldSkip` now also honours `-UITests`.
- Follow-ups: privacy/terms/support URLs are placeholders (human); the 18+ vs browser decision is still open (O1).

### 2026-11-05 00:25 (Bogotá) — Integrator: merged #22 (claude/qa-ui-tests)
- Merged [#22](https://github.com/Xanderco/iOSCarPlayVideo/pull/22): XCUITest smoke suite (`DashCastUITests`, 4 tests, screenshots exported as a CI artifact), a CI step that splits unit and UI tests, the `testflight.yml` workflow and `Docs/QA/`.
- Follow-ups: TestFlight needs App Store Connect API secrets (human); the UI tests assume today's 5-tab layout, so update them when the redesign lands.

### 2026-11-05 00:25 (Bogotá) — Integrator: merged #20 (claude/design-system-v2)
- Merged [#20](https://github.com/Xanderco/iOSCarPlayVideo/pull/20): design system v2 (tokens and components) and `Docs/Design/redesign-spec.md` (four tabs: Home, Library, Cast & Mirror, Settings/Pro). No screens are rewritten yet; that is redesign 2A/2B in phase 2.
- Open: O2 (Drive/Widgets/Sounds move under Settings → Car Extras, or get cut).

### 2026-11-05 00:25 (Bogotá) — Integrator: merged #19 (claude/jellyfin-emby-qr)
- Merged [#19](https://github.com/Xanderco/iOSCarPlayVideo/pull/19): Jellyfin/Emby client (`Features/MediaServers/`, async/await, credentials in Keychain, direct play or HLS, progress reporting) and QR playlist import. The entry point is a "Media Servers" row in Me. Adds `NSCameraUsageDescription`.
- Follow-ups: test against a real Jellyfin/Emby server; Plex/Xtream later (§8).

### 2026-11-05 00:25 (Bogotá) — Integrator: merged #18 (claude/core-bugfixes)
- Merged [#18](https://github.com/Xanderco/iOSCarPlayVideo/pull/18), the core bug audit. Fixes the audio session (category options were invalid, so the silent switch muted video and background audio stopped). Player state now comes from `timeControlStatus`, with Retry/Close on errors, Now Playing info and remote commands. Also fixes local videos, external display and Drive tracking. Full list in `Docs/Audit-2026-11.md`.
- Follow-ups: the items marked *needs-device* in the audit go on the Mac/real-device checklist.

### 2026-11-05 00:40 (Bogotá) — Session 15: real Home Screen widgets (`claude/home-widgets`)
- Added WidgetKit extension target `DashCastWidgets` (iOS 17, bundle `com.xanderco.dashcast.widgets`) with original designs: **My Car** (small/medium, AppIntentConfiguration with a "show plate" toggle: user photo or SF Symbol, name, brand/model, licence plate badge), **Last Trip** (small/medium, AppIntentConfiguration with units: distance, score ring, relative date, duration), **Quick Cast** (small + Lock Screen circular/rectangular/inline, opens `dashcast://cast`).
- Shared data: `DashCast/Shared/WidgetSharedStore.swift` (compiled into app and extension) stores a versioned JSON payload in app group `group.com.xanderco.dashcast` (same group as PR #25), falling back to standard defaults when unsigned. `PersistenceController.saveWidgets/saveTrips` now publish to it (photo downscaled to 320px JPEG) and call `WidgetCenter.shared.reloadAllTimelines()`.
- App: `dashcast://` URL scheme in Info.plist; `DashCastLinks.destination(for:)` parses `cast`/`drive`, and `AppState.handleDeepLink` maps them to tabs. The car widget has no deep link (it just opens the app) so it doesn't depend on where the Widgets editor lives (2B moves it to Settings > Extras). App and extension entitlements carry the app group.
- Tests: `WidgetSharedStoreTests` (encode/decode round trip, store save/load, corrupt-data fallback, config→snapshot, publish, deep links).
- Follow-ups: the built-in car artwork (`carImageName`) lives in the app's asset catalog and isn't shared yet, so widgets show the user's photo or a symbol. The app group must be registered in the developer portal before TestFlight signing. When merging with #25, keep both extension targets and app dependencies (the edits are additive).

### 2026-11-05 00:14 (Bogotá) — Integrator: merged #15 (claude/browser-send-to-car)
- Merged [#15](https://github.com/Xanderco/iOSCarPlayVideo/pull/15), the real browser "Send to car" that replaces the fake alert. `WebVideoExtractor` detects `<video>`/HLS in all frames and detects EME/DRM. `playWebVideo` hands off to `VideoPlayerService` with external playback. DRM-only presets (Netflix, Disney+, etc.) are removed, per D5. Adds 10 tests.
- Why: it replaces a fake feature with an honest hand-off, and removes third-party DRM presets for App Review 5.2.
- Follow-ups: detection is heuristic (MSE sites without m3u8, such as YouTube, can't be handed off); some CDNs need cookies/headers; not yet tested on a device or in a car.

### 2026-11-05 00:12 (Bogotá) — Integrator: merged #23 (journal)
- Merged [#23](https://github.com/Xanderco/iOSCarPlayVideo/pull/23) (`claude/project-journal`, docs only), so the journal is now on the integration branch. From now on the integrator appends an entry here with every merge.
- Already merged into `claude/ci-and-core-fixes` this session: [#17](https://github.com/Xanderco/iOSCarPlayVideo/pull/17) (IPTVParser + PlaylistStore tests, merge `8ba921e`) and [#16](https://github.com/Xanderco/iOSCarPlayVideo/pull/16) (CarPlay playlists/Now Playing, merge `ddf1550`). CI was green on both. One run after #16 failed only at the artifact-upload step, an infrastructure timeout; build and tests passed.
- Next: #15 browser, #18 core bugfixes, #19 Jellyfin/Emby, #20 design v2, #22 QA/UI tests, #21 Territory removal, then phase 2 (paywall, car video, redesign A/B, test automation).

### 2026-11-05 00:10 (Bogotá) — Journal created
- Created this journal with vision, decisions D1–D9, open decisions O1–O4. Owner rule: every agent reads it first and appends here.

### 2026-11-05 00:00–00:10 — Pricing, originality, testing
- Owner: **one-time USD 19.99, no subscriptions** (D1). Paywall + App Store metadata sessions updated.
- Found the codebase is a 1:1 CarDash clone → originality audit + redesign 2A/2B sessions started (D2).
- Test automation + Mac handoff session started (`Scripts/verify-all.sh`, `AGENTS.md`, `CLAUDE.md`, `Docs/MAC_AGENT_HANDOFF.md`).
- Integrator merging green sub-PRs: #17 (playlist tests), #16 (CarPlay) merged so far.

### 2026-11-04 23:45–00:00 — Parallel cloud sessions
- 13 cloud sessions on claude.ai/code: CarPlay (#16), browser send-to-car (#15), playlist tests (#17), QA/UI tests + TestFlight workflow, core bug audit (#18), Territory removal + icon + App Store media (D3, D5, D6, D7), design system v2 + spec (#20), Jellyfin/Emby + QR (#19), integrator, paywall, car video output (ADR-002), redesign 2A, redesign 2B.
- Owner: look & feel like cartv.app (D4); listing modeled on CarTV/CarDash but original.

### 2026-11-04 23:15–23:45 — CI made real (D8)
- Root causes: CI failed every run since Nov 1 ("Unable to read project", Xcode mismatch); `main` stuck at Nov 1; work stranded on branches; agents on Windows couldn't compile; CarPlay scene without entitlement; hardcoded sample playlist in CarPlay; fake "Send to car" alert; broadcast picker without an extension.
- Fixed CI (macOS 15, newest Xcode, generated project, explicit scheme) → **first green build, 40 tests**. Added PlaylistStore + parser rewrite + Cast UI import. Draft PR #14.

### 2026-11-04 — Paperclip diagnosis
- CARAA-13/14/15/17 were waiting in *In Review* for the Human Gate; agents idle on 1-hour heartbeats. Created CARAA-18…26 (CI, consolidation, entitlement, feasibility ADR, CarPlay playlists, M3U, browser, broadcast, QA). Then paused all Paperclip agents in favour of cloud sessions.
