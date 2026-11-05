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
- [ ] On the Mac: hand `Docs/MAC_AGENT_HANDOFF.md` to an agent (`brew install xcodegen xcbeautify`, then `make verify`) until green; do the manual checklist (real device, CarPlay Simulator, AirPlay, broadcast, TestFlight) in HANDOFF §7.

## 8. Next steps (beyond current tasks)

1. Finish phase-2 integration (paywall, car video, redesign A/B, test automation) with CI green on `verify-all.sh`.
2. Mac run: full test pass + manual checklist; fix what simulators can't catch.
3. TestFlight build → owner tests in a real car.
4. App Store submission with `AppStoreMedia/` + review notes (demo playlist, passenger-only statement).
5. Later: localization (start with Spanish), Plex/Xtream support, subtitles, software decoding fallback (MKV/HEVC), DLNA receiver — only after the core is solid and original.

---

## Log

### 2026-11-05 00:45 (Bogotá) — Test automation: verify-all.sh + Mac handoff ([#26](https://github.com/Xanderco/iOSCarPlayVideo/pull/26))
- **What changed:** Added `Scripts/verify-all.sh` and `make verify` as the single command that decides "done". CI now runs only this script (D8), so CI and the Mac run identical steps. Added app test hooks `-uiTesting`, `-stubNetwork` (in-app `StubNetwork`; no live network) and `-seedDemoData`. Added the `CarPlayInterfaceControlling` seam so the CarPlay scene can be smoke-tested with a mock controller. Fixed the Favorites sheet, which never listed favorites. Added accessibility identifiers. Added new unit suites for StoreKit (`SKTestSession`: purchase, restore, refund, Ask to Buy, failure), CarPlay, the stubbed network, launch config and local playback (a bundled 8 KB clip), plus `DashCastUITests` (24 flows). Added `AGENTS.md`, `CLAUDE.md` and `Docs/MAC_AGENT_HANDOFF.md`, all with this journal as rule #1.
- **Why:** The owner hands the repo to a Mac agent with "run it". One script plus written rules (D9: no skips, no lowered thresholds) makes "green" mean the same thing everywhere.
- **Results:** First CI run of `verify-all.sh` ([run 41973244471](https://github.com/Xanderco/iOSCarPlayVideo/actions/runs/41973244471)): build OK, **136 tests, 132 passed, 0 skipped, 4 failed**. All failures were StoreKit-related. (1) Refund revocation is async, so the test now polls with a bound. (2) The purchase-alert button query raced. (3) The restore UI test assumed a manual Restore, but opening the paywall already restores entitlements automatically and closes the paywall, so the test now asserts that real behaviour (justified, D9). These fixes were pushed in the follow-up commit; confirm that CI is green on PR #26. If the refund test still fails, investigate `StoreKitManager.updatePurchasedStatus` and refunded transactions (possible real bug). DashCast.app line coverage **65.67%**; `COVERAGE_MIN` set to **60%**.
- **Follow-ups (Mac agent; see HANDOFF §6):** These tests are still TODO: the onboarding safety notice (#21; `-uiTesting` wipes defaults, so the notice will need handling in `DashCastUITestCase.launch()`), Jellyfin/Emby add-server with `StubNetwork` fixtures and QR manual entry (#19), the paywall id change to `pro.lifetime` (update `.storekit` and `PaywallUITests`), and the redesign 2A/2B identifiers. Also browser Send-to-car against a local HTML page, core-bugfix local videos list, raising `COVERAGE_MIN` above 60%, and the HANDOFF §7 manual checklists.

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
