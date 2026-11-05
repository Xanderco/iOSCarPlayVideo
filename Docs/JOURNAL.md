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
| D9 | Tests are never disabled/skipped to get green; fix code or test with justification. | 2026-11-05 | Owner wants "everything must pass" honestly. |

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
- **O2** Drive / Widgets / Sounds: keep as secondary "Extras", or drop to sharpen the video focus?
- **O3** Which car-video path to promise (see ADR-002): AirPlay-when-parked on supported head units, screen mirroring, DLNA receive.
- **O4** CarPlay entitlement category to request from Apple (likely Audio/Video-adjacent per ADR).

## 7. Human to-dos

- [ ] Request CarPlay entitlement — developer.apple.com/contact/carplay.
- [ ] App Store Connect: create non-consumable `pro.lifetime`, USD 19.99, Family Sharing.
- [ ] Privacy policy, terms (EULA) and support URLs (placeholders in metadata).
- [ ] Check GitHub Actions minutes / billing (private repo).
- [ ] Close superseded PRs #11, #12, #13; review and merge #14.
- [ ] On the Mac: hand `Docs/MAC_AGENT_HANDOFF.md` to an agent; run `Scripts/verify-all.sh` until green; do the manual checklist (real device, CarPlay Simulator, AirPlay, TestFlight).

## 8. Next steps (beyond current tasks)

1. Finish phase-2 integration (paywall, car video, redesign A/B, test automation) with CI green on `verify-all.sh`.
2. Mac run: full test pass + manual checklist; fix what simulators can't catch.
3. TestFlight build → owner tests in a real car.
4. App Store submission with `AppStoreMedia/` + review notes (demo playlist, passenger-only statement).
5. Later: localization (start with Spanish), Plex/Xtream support, subtitles, software decoding fallback (MKV/HEVC), DLNA receiver — only after the core is solid and original.

---

## Log

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
