# DashCast Redesign Spec (v2)

Status: **Phase 1 — design system landed** (`DashCast/Core/DesignSystem`). Screens migrate in Phase 2.
Owner: Product/Design · Last updated: 2026-11-05

> Direction: a dark, native-feeling iOS video & IPTV player that is equally good on the
> iPhone in your hand and on the car screen. The north star is "open app → your channels → playing in two taps".
> We take *inspiration* from the category (e.g. cartv.app: dark UI, vivid accent, big rounded tiles,
> persistent mini player, landscape car mode, sources → groups → channels).
> We do **not** reuse anyone's name, copy, logos, screenshots or exact colors. Everything here is DashCast-owned.

---

## 1. Principles

1. **Content first.** Channels, artwork and logos carry the color; chrome stays neutral and quiet.
2. **Two taps to play.** Home always shows Continue Watching / Favorites; the mini player keeps playback alive while browsing.
3. **Glanceable in the car.** Car mode and CarPlay use oversized targets (≥ 72 pt), large type, high contrast, no dense text.
4. **Native, not themed.** System navigation, lists, sheets, materials, SF Symbols, Dynamic Type and VoiceOver everywhere.
5. **Honest states.** Every list has designed empty, loading, error and offline states (see §6).
6. **Private by default.** No account; all data on device. The UI never implies cloud sync we don't have.

---

## 2. Design system (implemented in Phase 1)

All tokens live in `DashCast/Core/DesignSystem`. Old v1 names (`dashYellow`, `dashSurface`, `ThemeFonts`, …)
still compile as **deprecated aliases** mapped to v2 roles, so the app already renders in the new palette.
Phase 2 replaces each usage via the compiler's *rename* fix-it and then deletes the aliases.

### 2.1 Color — `ThemeColors.swift`

Adaptive (light/dark + Increase Contrast variants) via dynamic `UIColor`. Brand accent is **DashCast Signal Green**.

| Role | Dark | Light | Use |
|---|---|---|---|
| `dcBackground` | `#07090B` | `#F2F3F5` | App canvas (OLED black in dark) |
| `dcBackgroundElevated` | `#0F1215` | `#FFFFFF` | Sheets, grouped canvas |
| `dcSurface` | `#15191D` | `#FFFFFF` | Cards, tiles, rows |
| `dcSurfaceRaised` | `#1E2328` | `#E9EBEE` | Pressed rows, search field, nested |
| `dcSeparator` / `dcStroke` | `#262C32` / `#232A30` | `#D6D9DE` / `#DDE0E4` | Hairlines, card outlines |
| `dcTextPrimary` | `#F4F6F8` | `#0B0E11` | Titles, body |
| `dcTextSecondary` | `#A3ABB4` | `#545B64` | Subtitles, metadata |
| `dcTextTertiary` | `#6E7781` | `#7D848D` | Placeholders, disabled |
| `dcAccent` | `#2BE47F` | `#0E9F4E` | Selection, primary buttons, now-playing, progress |
| `dcAccentPressed` | `#1FC46A` | `#0A8240` | Pressed accent |
| `dcAccentSoft` | `#0E2B1C` | `#DDF5E7` | Selected chips, secondary button fill |
| `dcOnAccent` | `#04130A` | `#FFFFFF` | Text/icons on accent fill |
| `dcLive` | `#FF4D4F` | `#E5252A` | LIVE badge |
| `dcDanger` / `dcWarning` / `dcSuccess` / `dcInfo` | red / amber / green / blue | darker variants | Status |
| `dcPro` | `#F5C451` | `#B7791F` | Pro / Lifetime only |
| `dcScrim`, `dcVideoChrome` | — | — | Over-video overlays, car mode / CarPlay fixed-black |

Gradients: `dcAccentGradient`, `dcProGradient`, `dcArtworkScrim`, `dcStatusRamp`.

Rules: accent is for *state and primary action only* (never large background areas); the light accent is
deepened so accent-colored text keeps ≥ 4.5:1 on white; status never relies on color alone (icon + label).

**Appearance:** v2 supports light and dark. Phase 1 keeps the app forced to `.dark` (`DashCastApp`), Phase 2
adds Settings → Appearance (System / Dark / Light), default **Dark**. Car mode, the full player and the
external/CarPlay display are always dark.

### 2.2 Typography — `ThemeFonts.swift` (`DSTypography`)

Built on Apple text styles → scales with Dynamic Type. Headings use SF Pro Rounded, body uses SF Pro.

| Token | Base | Use |
|---|---|---|
| `largeTitle` | Large Title, bold rounded | Custom headers, car clock |
| `title` | Title, bold rounded | Hero / paywall |
| `title2` | Title 2, semibold rounded | `SectionHeader` |
| `title3` | Title 3, semibold rounded | Tile titles, empty-state title |
| `headline` | Headline, semibold | Row titles, buttons |
| `body` / `callout` / `subheadline` / `footnote` | system | Copy, metadata |
| `caption` | Caption, medium | Timestamps |
| `badge` | Caption 2, bold rounded | LIVE / PRO / M3U badges |
| `numeric` | Body, rounded, monospaced digits | Counts, time codes |
| `carTitle` / `carHeadline` / `carBody` | Large Title / Title 2 / Title 3 | Car mode |

`.dsCarModeTypography()` clamps Dynamic Type to `.xLarge … .accessibility3` in car mode.

### 2.3 Spacing, radius, layout — `DesignTokens.swift`

- `DSSpacing`: 2 · 4 · 8 · 12 · 16 · 24 · 32 · 48; `screenGutter` 16, `carGutter` 32, `gridGap` 12, `sectionGap` 28.
- `DSRadius` (always `.continuous`): xs 6 (badges) · sm 10 (logos) · md 14 (buttons, search) · lg 20 (cards, mini player) · xl 26 (source tiles) · sheet 32.
- `DSLayout`: `minTapTarget` 44, `carTapTarget` 72, `channelLogo` 48, `miniPlayerHeight` 64, `sourceTileMinWidth` 156, button heights 52 / 72 (car).
- `DSStroke`: hairline 0.5, regular 1, focus 2. `DSShadow`: `card`, `floating`.
- `DSMotion`: `quick`, `standard`, `emphasized`; `DSMotion.animation(_:reduceMotion:)` returns `nil` when Reduce Motion is on.

### 2.4 Materials

`DSMaterial.chrome` (ultra-thin: mini player, floating tab bar), `.bar` (regular: sticky search/header), `.panel`
(thick: car-mode panels over video). `.dsMaterialBackground(_:)` falls back to solid `dcSurfaceRaised` when
**Reduce Transparency** is on. `.dsCard()` is the standard card treatment.

### 2.5 Components (`Components/`, each with `#Preview`s in dark, light and large type)

| Component | Purpose | Key API / states |
|---|---|---|
| `SourceTile` | Big rounded tile for a source | `title, subtitle, systemImage, tint, badge, status: .ready/.loading/.error(msg)`; `SourceTile.add {}` dashed tile |
| `ChannelRow` | Row for channel / episode / file / bookmark | logo + monogram fallback, LIVE badge, now-playing waveform, favorite star (also VO action), resume `progress`, `isUnavailable` dimmed; `init(channel:)` |
| `ChannelLogo`, `LiveBadge` | Building blocks | async logo with monogram fallback |
| `SectionHeader` | Shelf/section title | `title, subtitle, count, actionTitle = "See All", action`; header trait |
| `MiniPlayerBar` | Persistent now-playing bar | `title, subtitle, artworkURL, isPlaying, isLive, isBuffering, progress, onExpand, onPlayPause, onClose` |
| `PrimaryButton` / `DSButtonStyle` | All buttons | `kind: .primary/.secondary/.tertiary/.destructive`, `size: .compact/.regular/.car`, `isLoading`, `fullWidth` |
| `EmptyStateView` | Empty / error / loading | `init(systemImage:title:message:actionTitle:action:…)`, `.error(message:retry:)`, `.loading(_:)` |
| `SearchField` | Channel/source search | clear button, Cancel when focused, focus ring, `.search` submit |

Legacy components stay for now, restyled on v2 tokens: `GlowButton` → replace with `PrimaryButton`;
`AutomotiveCard` → `.dsCard()`; `NeonGaugeView` (Drive only); `LiquidCapsuleTabBar` → replaced by the native
`TabView` in Phase 2 (see §3).

---

## 3. Information architecture

```
TabView (native, accent-tinted)          + MiniPlayerBar docked above the tab bar on every tab
├── Home            continue watching · favorites · recents · source shelves · search
├── Library         Sources → Groups → Channels (+ add/manage sources, local files)
├── Cast & Mirror   AirPlay / CarPlay casting, screen mirroring, web video, car mode entry
└── Settings        DashCast Pro, playback, appearance, car mode, extras, help, about
Full-screen layers: Player (portrait/landscape) · Car Mode (landscape) · Paywall sheet · Onboarding
```

| v2 tab | SF Symbol | Replaces |
|---|---|---|
| Home | `house.fill` | Cast tab's home content |
| Library | `square.stack.fill` | "Media Sources" + "Favorites" sheets in `CastHomeView` |
| Cast & Mirror | `airplayvideo` | CarPlay status card, mirroring sheet, web browser entry |
| Settings | `gearshape.fill` | Me tab |

**Removed:** Territory (feature deleted). **Moved out of the tab bar:** Drive, Widgets and Sounds become
entries in *Settings → Car Extras* (and stay reachable by deep link `-initialTab`). Rationale: the product is a
video/IPTV player; four tabs keep the bar uncluttered. *Open question for the owner:* keep Car Extras at all
in v2, or cut them in a follow-up?

`AppState.TabItem` becomes `home, library, cast, settings`. The `-initialTab` launch argument keeps working
(old values `cast`/`me` map to `cast`/`settings`; `drive`/`widgets`/`sounds` open Settings and push the extra).

---

## 4. Screens

Layout notes assume iPhone portrait unless stated; all screens use `dcBackground`, `screenGutter` 16, and the
large-title navigation bar. Every scrollable screen leaves bottom inset for the mini player (64 + 8).

### 4.1 Home

- **Nav:** large title "DashCast"; trailing toolbar: `+` (Add Source sheet), Pro crown if not Pro.
- **SearchField** pinned under the title (`.bar` material when scrolled). Typing switches the content to
  search results: Channels (ChannelRow), Groups, Sources; results across all sources, debounced 200 ms.
- **Sections (vertical scroll, `sectionGap` 28):**
  1. *Continue Watching* — horizontal shelf of 16:9 cards with resume `progress`; hidden if empty.
  2. *Favorites* — horizontal shelf of logo tiles (ChannelLogo 72 + name); "See All" → Library › Favorites.
  3. *Recently Watched* — up to 8 `ChannelRow`s.
  4. *Per-source shelves* — `SectionHeader(source.title, count:)` + horizontal shelf of top groups;
     tapping a group opens Group Detail. Channels marked unavailable are hidden from Home (shown dimmed in Library).
  5. *Your Sources* — `LazyVGrid` of `SourceTile`s + `SourceTile.add`.
- **States:** first launch / no sources → `EmptyStateView` "Add your first source" (primary Add Source,
  secondary "Try a sample playlist"); loading (first import) → `EmptyStateView.loading`; all sources failing →
  inline error banner with Retry; offline → banner "You're offline — local videos still work".

### 4.2 Library (Sources → Groups → Channels)

- **Sources list:** grid of `SourceTile` (2 columns on iPhone, adaptive on iPad) with status
  (`.loading` while refreshing, `.error` with reason). Swipe/context menu: Refresh, Rename, Edit URL, Remove (destructive, confirm).
  Fixed tiles: *Favorites*, *On This iPhone* (local files), *Web Bookmarks*. Toolbar: `+`, Edit.
- **Add Source sheet** (medium/large detents): segmented *Link · File · Server · QR*.
  Link = URL field + optional name + `PrimaryButton("Add", isLoading:)`; File = Files importer (M3U/M3U8);
  Server = Jellyfin/Emby (Phase 3, shown as "Coming soon"); QR = camera scan. Inline validation errors under fields.
- **Source detail (Groups):** large title = source name; `SearchField`; group chips (horizontal) for quick filter;
  list of groups with channel counts and first 3 logos; "All Channels" row first.
- **Group detail (Channels):** `List` of `ChannelRow` with favorite toggles; sort menu (Default, A–Z, Recently watched);
  unavailable channels dimmed with "Unavailable" value.
- **Favorites:** `ChannelRow` list, reorderable in Edit mode; empty state "No favorites yet — tap ☆ on any channel".
- **On This iPhone:** grid of video thumbnails (16:9, `DSRadius.md`), import from Files / Photos; empty state with both actions.
- **States:** per-source loading spinner tile; parse errors as `EmptyStateView.error` with *Try Again* and *Edit Link*;
  empty group → "This group has no playable channels".

### 4.3 Player (full screen)

- Portrait: 16:9 video top, below it title, LIVE badge/source, and the *Up Next in group* list (`ChannelRow`).
  Swipe down → collapses into `MiniPlayerBar`.
- Landscape: edge-to-edge video, auto-hiding controls on `dcScrim`: back, title, AirPlay route picker,
  PiP, subtitles/audio menu, previous/next channel (one tap), play/pause, scrubber (VOD only), "Car Mode" button.
- **States:** buffering spinner centered; stream error overlay → `EmptyStateView.error` (dark) with *Try Again*
  and *Next Channel*; geo/HTTP errors show readable reason.

### 4.4 Mini player

`MiniPlayerBar` docked above the tab bar on all tabs (via `safeAreaInset(edge: .bottom)`), appears with
`DSMotion.standard` when playback starts, persists across navigation, hides in car mode/full player.
Tap → full player; play/pause; × stops and dismisses. VoiceOver: "Now playing: <title>", actions Play/Pause, Stop.

### 4.5 Car Mode (landscape, Pro)

Entered from Player, Cast & Mirror, or automatically when CarPlay/external display connects (setting).
- Always dark (`dcVideoChrome`), `.dsCarModeTypography()`, `carGutter` 32, min targets 72 pt.
- **Layout:** left 60 % video (or artwork for audio-only); right panel (`DSMaterial.panel`) with current channel
  in `carHeadline`, big `PrimaryButton(size: .car)` row: Previous · Play/Pause · Next, plus a vertical list of the
  current group (rows 72 pt, `carBody`). Optional clock in `carTitle`.
- No text input, no nested navigation deeper than one level, no scrubbing while moving.
- Paywall: non-Pro users see a single car-mode preview screen with "Unlock with Pro".

### 4.6 Cast & Mirror

- **Status card** (`.dsCard()`): connection state (CarPlay / AirPlay / External display) with icon + text,
  `AirPlayRoutePicker` button, "How to connect" link (opens `CarCastGuideModalView`).
- **Actions grid** of `SourceTile`s: *Mirror iPhone Screen* (broadcast picker), *Cast a Video* (AirPlay route picker
  + current item), *Web Video* (opens `WebVideoBrowserView`), *Car Mode*.
- **States:** not connected → hint text + guide button; connected → accent status with route name;
  mirroring active → banner with Stop; Pro-gated items show PRO badge and open paywall.

### 4.7 Settings & Pro

Grouped `List` (`dcBackgroundElevated`):
1. **Pro card** (top): `dcProGradient` accent, "DashCast Pro — Lifetime" with `PrimaryButton`; when owned, shows "Pro ✓" and Restore.
2. **Playback:** default quality, hardware decoding, subtitles, resume behavior, hide unavailable channels.
3. **Car:** auto car mode on connect, speed units (km/h / mph), keep screen awake.
4. **Appearance:** System / Dark / Light, app icon (later).
5. **Car Extras:** Drive (trips), Widgets, Sounds — push existing screens.
6. **Data:** Refresh all sources, clear cache, export/import sources.
7. **Help & About:** Guide, Shortcuts, Feedback, Usage stats (debug), version.

**Paywall sheet** (`LifetimePaywallView`): single-purchase story, feature list with SF Symbols, primary
`PrimaryButton` with price, `isLoading` during purchase, Restore as tertiary; error alert on failure.

### 4.8 Onboarding (new, Phase 3)

Three pages max: Welcome → Add a source (inline Link/File) → Car tips. Skippable; ends on Home.

---

## 5. CarPlay

CarPlay uses Apple templates only (no custom drawing) — the design system influences copy, icons and order,
not visuals. `DashCast/CarPlay/` is **not touched in Phase 1**.

Target template tree (Phase 2/3, subject to the CarPlay entitlement we hold):
- `CPTabBarTemplate`: **Home** (Continue Watching + Favorites, `CPListTemplate`), **Library**
  (sources → groups → channels, max depth per CarPlay limits; long lists paged with "More…"), **Cast**.
- Item rows: channel logo as `CPListItem` image (monogram fallback rendered via `ChannelLogo` → `UIImage`), LIVE in detail text.
- Selecting an item starts playback; video only renders on the external/CarPlay display when parked, per platform rules;
  the now-playing template handles audio.
- Error/empty: `CPListTemplate` with `emptyViewTitleVariants` ("No favorites yet", "Add sources on your iPhone").

---

## 6. State patterns (all screens)

| State | Pattern |
|---|---|
| Empty | `EmptyStateView` with icon in `dcAccentSoft` circle, one primary action, optional secondary |
| Loading (first) | `EmptyStateView.loading` centered; never block already-cached content |
| Loading (refresh) | Pull-to-refresh + `SourceTile(status: .loading)`; rows stay interactive |
| Error (screen) | `EmptyStateView.error(message:retry:)`, human message + Try Again |
| Error (item) | Inline: `SourceTile(status: .error)` / dimmed `ChannelRow(isUnavailable:)` |
| Offline | Top banner, local content still browsable |
| Pro-gated | PRO badge (`DSTypography.badge`, `dcPro`) + opens paywall sheet |

---

## 7. Accessibility & Dynamic Type

- All text uses `DSTypography` text styles; fixed sizes are allowed only for video overlays and SF Symbol glyphs sized from `@ScaledMetric`.
- Layouts tested from **xSmall to AX5**. At accessibility sizes: shelves become vertical lists, `SourceTile` grid
  drops to 1 column, `ChannelRow` subtitles wrap, toolbar text buttons collapse to icons with labels.
- Hit targets ≥ 44 pt (72 pt car mode). Favorite star, mini player buttons and search clear meet this.
- VoiceOver: rows are single elements with label ("Name, Live, Group") + value ("Now playing, Favorite, 60 % watched")
  + custom actions (favorite). Headers carry `.isHeader`. Decorative images hidden.
- Contrast: text ≥ 4.5:1, large text/icons ≥ 3:1 in both appearances; Increase Contrast swaps to HC variants.
- Reduce Motion: no scale/spring effects (`DSMotion.animation`), crossfades instead.
- Reduce Transparency: materials fall back to solid surfaces.
- Color is never the only signal (LIVE has text, errors have icons, selection has checkmark/trait).
- Localization: no text baked into images; layouts tolerate +40 % string length and RTL.

---

## 8. File mapping (existing → redesigned)

| Existing file | v2 destination | Phase 2 action |
|---|---|---|
| `Core/Navigation/MainTabView.swift` | Root `TabView` (Home, Library, Cast & Mirror, Settings) + mini player inset | Rewrite |
| `Core/DesignSystem/Components/LiquidCapsuleTabBar.swift` | Replaced by native tab bar | Delete after migration |
| `Core/DesignSystem/Components/GlowButton.swift` | `PrimaryButton` | Migrate call sites, delete |
| `Core/DesignSystem/Components/AutomotiveCard.swift` | `.dsCard()` | Migrate, delete |
| `Core/DesignSystem/Components/NeonGaugeView.swift` | Settings › Car Extras › Drive | Keep (restyled) |
| `App/AppState.swift` | New `TabItem` cases, mini-player/now-playing state | Update |
| `App/DashCastApp.swift` | Appearance setting instead of forced `.dark` | Update |
| `Features/Cast/CastHomeView.swift` | Split → **Home** (shelves/search), **Library** (sources/favorites/add stream), **Cast & Mirror** (status, mirroring) | Rewrite & split |
| `Features/Cast/PlaylistStore.swift` | Data source for Home/Library (unchanged) | Not touched |
| `Features/Cast/IPTVParser.swift` | Unchanged | Not touched |
| `Features/Cast/AutomotiveVideoPlayerView.swift` | **Player** (portrait/landscape) + **Car Mode** | Rewrite on tokens |
| `Features/Cast/VideoPlayerService.swift` | Drives `MiniPlayerBar` + Player | Add now-playing publishers |
| `Features/Cast/LocalVideoManager.swift` | Library › On This iPhone | Keep logic |
| `Features/Cast/WebVideoBrowserView.swift` | Cast & Mirror › Web Video | Not touched (entry point only) |
| `Features/Cast/ScreenBroadcastPickerView.swift` | Cast & Mirror › Mirror | Keep |
| `Features/Cast/AirPlayRoutePickerRepresentable.swift` | Player + Cast & Mirror | Keep |
| `Features/Cast/CarCastGuideModalView.swift` | Cast & Mirror › How to connect | Restyle |
| `Features/Cast/CarPlayExternalDisplayView.swift` | External display / Car mode surface | Restyle (always dark) |
| `Features/Cast/ExternalDisplayManager.swift` | Unchanged | Keep |
| `Features/Cast/CarPlaySimulatorView.swift` | Debug-only preview under Settings › Help | Keep, hide in release |
| `Features/Me/MeHomeView.swift` | **Settings & Pro** | Rewrite as grouped list |
| `Features/Me/FeedbackView.swift` | Settings › Help › Feedback | Restyle |
| `Features/Pro/LifetimePaywallView.swift` | Paywall sheet | Restyle (`dcPro`, `PrimaryButton`) |
| `Features/Drive/*` (`DriveHomeView`, `TripSummaryView`, `DriveSettingsView`, `DriveTrackingPermissionsSheet`, `SpeedGradientRouteView`, services) | Settings › Car Extras › Drive | Restyle only |
| `Features/Widgets/*` (`WidgetsHomeView`, `WidgetEditorView`, `CarPlayDashboardMockupView`, `VideoTrimmerView`, `VehicleCatalogService`) | Settings › Car Extras › Widgets | Restyle only |
| `Features/Sounds/*` (`SoundsHomeView`, `ShortcutsGuideView`, services) | Settings › Car Extras › Sounds; Shortcuts guide → Help | Restyle only |
| `Features/Territory/*` | — | **Remove** (separate PR) |
| `Core/Analytics/UsageMetricsView.swift` | Settings › Help › Usage (debug) | Restyle |
| `CarPlay/*` | CarPlay templates (§5) | Not touched in Phase 1 |

---

## 9. Phasing

1. **Phase 1 (this PR):** tokens, components, previews, deprecated aliases, this spec. No screen rewrites.
2. **Phase 2 (after open PRs merge):** new `TabView` + mini player; Home, Library, Cast & Mirror, Settings;
   migrate all `dash*` usages; delete aliases and legacy components; remove Territory.
3. **Phase 3:** Car Mode polish, CarPlay template refresh, onboarding, media servers, appearance setting.

## 10. Acceptance checklist (per screen in Phase 2)

- [ ] Uses only `dc*` colors / `DS*` tokens (no hex, no deprecated names)
- [ ] Empty, loading, error (and offline where relevant) states implemented
- [ ] Verified at Dynamic Type xSmall, Large, AX3; dark + light; Increase Contrast
- [ ] VoiceOver labels/values/actions; no unlabeled buttons
- [ ] Mini player does not cover content (bottom inset)
- [ ] Car mode targets ≥ 72 pt
