# DashCast 🚗💨 — Paperclip Autonomous Team Architecture & Execution Plan

**Project:** CarDash / DashCast Autonomous Operating Plan  
**Target Harness:** Paperclip (http://127.0.0.1:3100) & PACA (http://100.66.253.3:8080)  
**Repository:** `Xanderco/iOSCarPlayVideo`  
**Active Branch:** `feat/cardash-yellow-redesign`  
**Human Owner & Final Gatekeeper:** Alexander Benitez  
**Business Model:** Lifetime Access ($19.99 One-Time) — Zero Recurring Subscriptions

---

## 1. Executive Mandate & Company Vision

DashCast is built to become the **#1 aftermarket automotive companion app** for Apple CarPlay users worldwide.

Competitors like *CarDash*, *CarTV (@cartv_cast2car)*, and *PlayCar* have proven massive market demand: drivers crave personalized dashboard widgets, custom startup engine audio, and parked video casting on their vehicle displays. However, competitor apps are plagued by **predatory recurring subscriptions ($9.99/mo or $4.99/mo)**, brittle connection instructions, and poor automotive ergonomics.

### The DashCast Advantage
1. **Disruptive Pricing:** Pay Once ($19.99 Lifetime). Own Forever. Zero Subscriptions.
2. **Native CarPlay Integration:** Direct `CPTemplateApplicationSceneDelegate` inclusion on vehicle head-units, not just screen mirroring.
3. **Obsessive 1:1 Automotive UI:** High-contrast OLED True Black (`#0C0D10`), Electric Racing Yellow (`#FFE600`), and a floating tactile `LiquidCapsuleTabBar`.
4. **Autonomous Paperclip Execution:** Continuous competitor monitoring, automated test suites, and structured PACA governance.

---

## 2. Autonomous Agent Team Architecture ("The Hires")

In the Paperclip organizational model, autonomous execution is partitioned across specialized agent personas with clear ownership boundaries.

```
                     ┌───────────────────────────┐
                     │   Alexander Benitez       │
                     │  (Human Gatekeeper & VP)  │
                     └─────────────┬─────────────┘
                                   │ Approves "In Review" -> "Done"
                     ┌─────────────▼─────────────┐
                     │  Agent 1: Executive Lead  │
                     │  (Paperclip Orchestrator) │
                     └─────────────┬─────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         │                         │                         │
┌────────▼────────┐       ┌────────▼────────┐       ┌────────▼────────┐
│  Agent 2: iOS   │       │ Agent 3: Scout  │       │ Agent 4: Auto   │
│  Systems Lead   │       │ & Growth Scout  │       │ UX & Ergonomics │
│ (Swift/CarPlay) │       │ (Competitors)   │       │ (OLED/Parity)   │
└────────┬────────┘       └─────────────────┘       └─────────────────┘
         │
┌────────▼────────┐
│  Agent 5: QA &  │
│  Deploy Eng     │
│ (Xcode/Release) │
└─────────────────┘
```

### Agent 1: Executive Operator (`@dashcast-orchestrator`)
- **Mission:** Project management, task dispatch, backlog health, and PACA synchronization.
- **Responsibilities:**
  - Evaluates incoming media assets (`MediaToAnalyze`) and translates them into actionable engineering epics.
  - Enforces the **PACA Pre-Flight** and **Finish Gate** rules.
  - Coordinates cross-functional agent handoffs and maintains `PROGRESS.md` and `PAPERCLIP.md`.

### Agent 2: Principal iOS & CarPlay Systems Engineer (`@dashcast-ios-lead`)
- **Mission:** High-performance Swift/SwiftUI engineering, AVFoundation pipelines, and CarPlay framework integration.
- **Responsibilities:**
  - Owns `CPTemplateApplicationSceneDelegate`, `CPDashboardController`, and external screen scene lifecycle.
  - Implements video casting engines (IPTV M3U8, WebKit inline video extractors, PiP, local file streamers).
  - Optimizes CoreLocation / CoreMotion telemetry calculation with low battery overhead.
  - Manages StoreKit 2 Lifetime IAP transactions and restore flows.

### Agent 3: Competitor Intelligence & Growth Scout (`@dashcast-growth-scout`)
- **Mission:** Reverse-engineer top competitor features, track TikTok/Reels automotive trends, and optimize App Store conversion.
- **Responsibilities:**
  - Deconstructs rival releases (CarDash, CarTV, CarTube, DriveCast) on iOS App Store and TestFlight.
  - Maintains `MediaToAnalyze-Mapping.md` with every UI change, pricing shift, and user complaint.
  - Authors viral promo video scripts (TikTok/Reels/Shorts) highlighting our "No Subscription" lifetime model.
  - Audits App Store metadata, keywords, and screenshots for high ASO conversion.

### Agent 4: Automotive UX & Ergonomics Architect (`@dashcast-auto-designer`)
- **Mission:** Pixel-perfect 1:1 visual fidelity, automotive contrast compliance, and touch ergonomics.
- **Responsibilities:**
  - Enforces the Electric Racing Yellow (`#FFE600`) and OLED Deep Black (`#0C0D10`) design language.
  - Designs in-car widget templates (metal stamped plates, tachometer clocks, vinyl animations, vehicle garage renders).
  - Ensures minimum 48pt tap targets and glare-safe typography for vehicle lighting environments.
  - Maintains the in-app CarPlay Emulator (`CarPlaySimulatorView.swift`) reflecting exact 800×480 in-dash bezels.

### Agent 5: QA Automation & Release Engineer (`@dashcast-qa-deploy`)
- **Mission:** Bulletproof automated testing, simulator regression checks, and device deployment pipelines.
- **Responsibilities:**
  - Maintains `project.yml` (XcodeGen) and ensures clean reproducible builds.
  - Expands unit and integration test coverage across all core engines (Target: >85% coverage, 0 failures).
  - Executes automated UI test runs across target simulator configurations (`iPhone 17`, `iPhone SE 3rd gen`).
  - Manages code signing (`Team 96YG38576A`) and coordinates TestFlight builds for real-car field testing.

---

## 3. End-to-End Workflow for Features & Fixes

Every feature or bug fix processed by Paperclip follows an immutable 5-phase SOP:

```
[Phase 1: Intake & Competitor Diff]
        ↓
[Phase 2: PACA Pre-Flight & Branching]
        ↓
[Phase 3: Clean Architecture Implementation]
        ↓
[Phase 4: Automated Testing & Simulator Verification]
        ↓
[Phase 5: PACA Deliverable Report & Alexander Review Gate]
```

### Phase 1: Intake & Competitor Diff
1. Scout inspects new reference media or competitor App Store update.
2. Identifies:
   - What UI component is new?
   - What user problem does it solve?
   - Does it improve engagement without degrading safety?
3. Files a task draft with before/after screenshots.

### Phase 2: PACA Pre-Flight & Branching
1. Query PACA (`http://100.66.253.3:8080`) for the project `DashCast (iOSCarPlayVideo)` (`250c3694-30fa-414d-a9ec-aa541d659ad9`).
2. Move target task to **In Progress** (`b6f96a62-b54d-4596-b194-f7180cc271c3`).
3. Create feature branch off `main` or the active sprint branch following the format:
   `feature/<TASK_ID>-<slug>` (e.g., `feature/DI-8-drive-settings-notifications`).

### Phase 3: Clean Architecture Implementation
1. Follow existing codebase patterns:
   - Modern Swift 5.9+ / SwiftUI.
   - Observable patterns (`@MainActor`, `@StateObject`, `ObservableObject`).
   - Pure SwiftUI floating navigation (`LiquidCapsuleTabBar`) avoiding UIKit gesture conflicts.
   - Decoupled services (`VehicleCatalogService`, `SoundCatalogService`, `DriveLocationService`).
2. Run `xcodegen generate` if project structure or files are added.

### Phase 4: Automated Testing & Simulator Verification
1. Every new feature must be accompanied by dedicated unit tests in `DashCastTests/`.
2. Run test execution:
   ```bash
   xcodebuild test -project DashCast.xcodeproj -scheme DashCast -destination 'platform=iOS Simulator,name=iPhone 17'
   ```
3. Zero failures accepted before proceeding.
4. If visual verification is needed, launch simulator and capture artifact screenshots.

### Phase 5: PACA Deliverable Report & Human Gate
1. Commit changes with clear Conventional Commits format (`feat(...)`, `fix(...)`, `docs(...)`).
2. Push branch to `origin`.
3. Update PACA task description with standard Deliverable Report:
   - **Repository**
   - **Branch & Commit SHA**
   - **Key Deliverables**
   - **Verification Proof (Test logs & screenshot references)**
4. Move task in PACA to **In Review** (`25c2971e-6b10-4fbd-9fda-ae6f825a5eba`).
5. **Human Gate:** Only Alexander Benitez has authority to approve to **Done** (`cb550e71-512b-4b9e-b8c5-23ce3465cafc`).

---

## 4. Competitor Reverse-Engineering Engine ("Keep, Kill, Disrupt")

To win the category, DashCast systematically dissects competitors:

| Competitor Feature | Decision | Strategic Execution in DashCast |
| :--- | :---: | :--- |
| **Recurring Subscriptions ($9.99/mo)** | ❌ **KILL** | **Core Disruption:** Single $19.99 Lifetime Pass. Users pay once and own all present and future features forever. |
| **Aggressive First-Launch Paywall** | ❌ **KILL** | Allow users to freely explore all 5 tabs, configure widgets, and test sounds before gently presenting PRO. |
| **4-Row Cast Menu & Source Browser** | ✅ **KEEP** | 1:1 match with Media Source, Local Videos, Mirroring, and 20 preloaded online video links. |
| **CarPlay Startup & Shutdown Audio** | ✅ **KEEP** | Automotive soundboard with engine revs, turbo spools, sci-fi chimes, and 1-tap iOS Shortcuts setup. |
| **License Plate & Car Customization** | ⚡ **DISRUPT** | Enhanced live editor with stamped metal texture, customizable typography, color swatches, and live in-dash simulator. |
| **Screen Mirroring Lag** | ⚡ **DISRUPT** | Direct AVPlayer secondary window rendering on CarPlay display instead of heavy lossy screen re-encoding. |
| **CarPlay Home Grid Visibility** | ⚡ **DISRUPT** | Implement native `UIApplicationSceneManifest` CarPlay scenes so DashCast is an actual installed app on the car's head-unit. |

---

## 5. Continuous Testing & Vehicle Validation Protocol

### Tier 1: Automated Unit & Logic Testing (Local CI)
- **Frameworks:** XCTest, Swift Testing.
- **Coverage Areas:**
  - `AppStateTests`: Tab switching, launch arguments (`-initialTab`, `-carplaySimulator`), pro status.
  - `CastEngineTests`: IPTV M3U parser robustness, stream URL sanitization, playlist persistence.
  - `DriveTelemetryTests`: Speed calculations, distance aggregation, harsh braking/acceleration penalties, trip persistence.
  - `DriveSettingsAndNotificationTests`: Notification formatting, user preference encoding/decoding, threshold persistence.
  - `WidgetCatalogTests` & `WidgetCustomizationTests`: Vehicle catalog filtering, plate text, typography, color swatches, offset bounds.
  - `SoundEngineTests`: Sound catalog frequency validation, audio asset lookup, shortcut URL generation.
  - `StoreKitTests`: Lifetime product identifiers, purchase validation, restore state.

### Tier 2: In-App CarPlay Display Emulation
- Since developers cannot sit inside a car while writing code, `CarPlaySimulatorView.swift` replicates 3 distinct hardware modes:
  1. **App in CarPlay:** In-dash video player with aspect-fit video, progress bar, playback controls, and car dock.
  2. **CarPlay Dashboard:** Multi-window split view showing custom live widget, map, and now-playing media tile.
  3. **CarPlay Home Menu:** In-dash 4x2 app grid showing DashCast sitting proudly alongside native automotive apps.

### Tier 3: Physical Vehicle Road Testing Matrix
Before public App Store updates, execute testing on physical test vehicles:
1. **Connection Types:**
   - Wired Apple CarPlay (USB-A / USB-C direct).
   - Wireless Factory CarPlay (e.g., BMW iDrive, Ford SYNC 4).
   - Aftermarket Wireless Adapters (Carlinkit 5.0, Ottocast U2-Air).
2. **Safety & Distraction Lockout:**
   - Verify audio plays while driving.
   - Verify video pauses or displays safe audio visualizer when vehicle speed > 5 km/h if strict safety lockout is active.

---

## 6. Detailed Roadmap & Sprint Milestones

```
Sprint 1 (Done/In Review) ──► Sprint 2 (Active Next) ──► Sprint 3 (Scaling) ──► Sprint 4 (Launch)
Yellow Redesign               Dynamic Island &           Local RTSP/HTTP         Viral Marketing &
CarPlay Native Scene          Background Drive           Streaming Engine        Global App Store
```

### Sprint 1: Yellow Theme & Native CarPlay Parity (Status: In Review)
- [x] DI-13: Catalog 32 assets and author viral promotional script.
- [x] DI-6: Electric Yellow & Gold palette, floating Liquid Capsule dock.
- [x] DI-7: 1:1 Cast module, 20 streaming sources, native CarPlay scene delegates.
- [x] DI-8: Drive HUD, permissions sheet, `DriveSettingsView`, and `DriveNotificationService`.
- [x] DI-9: Widgets ecosystem, license plate customization, typography, and live sliders.
- [x] DI-10: 1:1 Soundboard, categories, and Shortcuts setup guide.
- [x] DI-11: Me profile, settings, about modal, and 1:1 feedback form.
- [x] DI-12: 14 test suites (40 tests passing), automated signing configured.

### Sprint 2: Dynamic Island & Background Drive Intelligence (Next Milestone)
- [ ] **ActivityKit Live Activity Extension (`DashCastLiveActivity`)**:
  - Live drive stats (speed, peak G, trip distance) on iPhone Lock Screen and Dynamic Island.
  - "Your CarPlay Your Style" widget teaser banner matching `Live Activity when Open and in Carplay.jpeg`.
- [ ] **CoreMotion Activity Classification**:
  - Automatic drive detection (`CMMotionActivityManager.isAutomotive`) to automatically trigger trip recording without tapping Start.
- [ ] **Trip Export & Social Share Cards**:
  - Render high-resolution Instagram Story image cards showing drive route, top speed, and vehicle avatar.

### Sprint 3: Low-Latency In-Car Streaming Server
- [ ] **Local Embedded HTTP/HLS Server (`GCDWebServer` / SwiftNIO)**:
  - Host local camera roll videos and transcoded streams on `http://127.0.0.1:8080` for instant CarPlay buffer-free playback.
- [ ] **Picture-in-Picture (PiP) Video Bridge**:
  - Enable background playback so navigation apps (Google Maps, Waze) can display while DashCast audio continues playing.

### Sprint 4: Viral Marketing, App Store Submission & Monetization
- [ ] **Production Video Shoot**:
  - Execute `Promotional-Video-Storyboard.md` inside a modern vehicle cockpit at night.
  - Publish across TikTok, Instagram Reels, and YouTube Shorts.
- [ ] **App Store Connect Submission**:
  - Complete App Store metadata, promotional text, 6.7" and 6.5" screenshots with yellow theme.
  - Request CarPlay entitlements from Apple.
- [ ] **Post-Launch A/B Testing**:
  - Test paywall price points ($14.99 vs $19.99 vs $24.99 Lifetime).

---

## 7. Operational Governance Rules for Paperclip Agents

1. **Strict Branching:** Never commit directly to `main`. Every unit of work must originate from a dedicated feature branch.
2. **No Regression:** All existing 14 test suites must pass before any branch is considered ready.
3. **PACA Synchronization:** Every pull request and release must have a corresponding task update in PACA with commit SHA and deliverable proof.
4. **Human Finality:** The agent may only move tasks to **In Review**. Alexander Benitez is the sole authority to mark tasks **Done**.
