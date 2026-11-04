# DashCast 🚗💨 — Paperclip Autonomous Company Architecture & Industry Best Practices

**Project:** CarDash / DashCast Autonomous Operating Plan  
**Target Harness:** Paperclip (`http://100.66.253.3:3100`), PACA (`http://100.66.253.3:8080`), and 1MCP Hub (`http://100.66.253.3:3050/mcp`)  
**Repository:** `Xanderco/iOSCarPlayVideo`  
**Active Branch:** `feat/cardash-yellow-redesign`  
**Human Owner & Final Gatekeeper:** Alexander Benitez  
**Business Model:** Lifetime Access ($19.99 One-Time) — Zero Recurring Subscriptions

---

## 1. Executive Summary & Product Thesis

DashCast is designed to become the **#1 aftermarket automotive companion app** for Apple CarPlay users worldwide.

Competitors like *CarDash*, *CarTV (@cartv_cast2car)*, and *PlayCar* have demonstrated immense organic demand across TikTok and the iOS App Store: car enthusiasts and daily commuters want personalized in-dash widgets, custom ignition sound effects, and parked video streaming on their vehicle screens. However, competitor apps suffer from:
1. **Predatory Subscription Pricing ($9.99/mo or $4.99/mo):** Users complain heavily about recurring fees for what is fundamentally a utility.
2. **Aggressive Paywalls:** Competitors lock the entire interface upon first launch before users even see the app work.
3. **Fragile Connection Instructions:** Users struggle with generic screen mirroring that lags or disconnects.

### The DashCast Disruption
- **Pay Once ($19.99 Lifetime). Own Forever.** Zero subscriptions.
- **Native CarPlay Scene Integration:** Direct `CPTemplateApplicationSceneDelegate` presence on the car's head-unit menu grid, not just passive screen casting.
- **Obsessive Automotive Ergonomics:** High-contrast OLED True Black (`#0C0D10`), Electric Racing Yellow (`#FFE600`), and a floating tactile frosted glass dock (`LiquidCapsuleTabBar`).
- **Autonomous Operating Structure:** Continuous competitor surveillance, automated test suites, and strict PACA/Paperclip governance.

---

## 2. Industry Best Practices for Autonomous AI Companies (Paperclip Governance)

Based on industry research on multi-agent software organizations (Anthropic Model Context Protocol standards, OpenAI Autonomous Agent Systems, and enterprise AI engineering guidelines), autonomous AI teams must be structured with strict separation of concerns, circuit breakers, and human-in-the-loop gates.

### Core Governance Principles
1. **Delegation Over Monolithic Execution:**
   The Executive/CEO agent never touches code or writes PRs directly. Work is triaged, decomposed into atomic subtasks, and routed to departmental specialists.
2. **Strict Pre-Flight & Checkout Gate:**
   - No code is touched without an existing task registered in PACA (`http://100.66.253.3:8080`) and checked out in Paperclip (`http://100.66.253.3:3100/api`).
   - Every task transitions to `in_progress` before work starts.
   - Work happens exclusively in isolated git worktrees (`feature/<TASK_ID>-<slug>`). Never commit to `main`.
3. **Deterministic Quality Gates (The Finish Protocol):**
   - No task is completed without passing 100% of automated test suites.
   - Every task update in PACA and Paperclip must contain a **Deliverable Report**:
     - Repository & Path
     - Branch (`feature/<TASK_ID>-<slug>`)
     - Commit SHA
     - Verification Proof (test pass logs, simulator verification)
4. **Human Finality (The Alexander Gate):**
   Agents only have authority to move tasks to **In Review** or create approval requests via `paperclipCreateApproval`. Only Alexander Benitez has the authority to transition work to **Done**.
5. **Heartbeat & Token Circuit Breakers:**
   Heartbeat worker runs are bounded by execution timeouts and token limits to prevent runaway loops. If a blocking dependency is encountered, the agent logs an escalation issue in Paperclip and yields.

---

## 3. Autonomous Team Roles ("The Hires")

```
                     ┌───────────────────────────┐
                     │     Alexander Benitez     │
                     │  (Human Owner & Approver) │
                     └─────────────┬─────────────┘
                                   │ Approves "In Review" -> "Done"
                     ┌─────────────▼─────────────┐
                     │  Agent 1: Executive Lead  │
                     │  (@dashcast-orchestrator) │
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

### 1. Executive Lead (`@dashcast-orchestrator`)
- **Role:** Chief of Staff / Product Director.
- **Responsibilities:**
  - Triages incoming feature requests, competitor shifts, and customer feedback.
  - Deconstructs epics into actionable child tasks in PACA and Paperclip.
  - Maintains `PROGRESS.md`, `PAPERCLIP.md`, and roadmap milestone timelines.
  - Ensures compliance with the Omni Memory Protocol.

### 2. Principal iOS & CarPlay Systems Engineer (`@dashcast-ios-lead`)
- **Role:** Technical Architect.
- **Responsibilities:**
  - Implements Swift 5.9+ / SwiftUI architecture, AVFoundation pipelines, and CarPlay framework delegates.
  - Owns `CarPlaySceneDelegate.swift`, `CarPlayDashboardSceneDelegate.swift`, and secondary display window management.
  - Optimizes CoreLocation / CoreMotion telemetry calculation with low battery overhead.
  - Implements StoreKit 2 Lifetime In-App Purchases and receipt validation.

### 3. Competitor Intelligence & Growth Scout (`@dashcast-scout`)
- **Role:** Growth & Market Intelligence.
- **Responsibilities:**
  - Continuously monitors rival apps on the App Store (CarDash, CarTV, PlayCar, CarTube).
  - Deconstructs rival releases, viral TikTok creative formats, and user dissatisfaction signals.
  - Authors high-converting 60-second video storyboards (TikTok/Instagram Reels/YouTube Shorts).
  - Drives App Store Optimization (ASO) keywords, subtitle copy, and screenshot sequencing.

### 4. Automotive UX & Ergonomics Architect (`@dashcast-designer`)
- **Role:** Design System & Ergonomics Lead.
- **Responsibilities:**
  - Maintains the signature Electric Racing Yellow (`#FFE600`) and OLED True Black (`#0C0D10`) design system.
  - Enforces strict automotive safety standards: minimum 48×48pt touch targets, high contrast for glare environments.
  - Creates custom widget assets (metal stamped license plates, tachometer clocks, retro vinyl animations).
  - Maintains the in-app CarPlay Emulator (`CarPlaySimulatorView.swift`) reflecting exact 800×480 vehicle bezels.

### 5. QA Automation & Release Engineer (`@dashcast-qa-deploy`)
- **Role:** Build & Release Engineer.
- **Responsibilities:**
  - Maintains `project.yml` (XcodeGen) to guarantee zero `.pbxproj` git merge conflicts.
  - Enforces 100% test pass rate across all 14+ unit and integration test suites.
  - Configures automatic code signing (`Team 96YG38576A`) and builds TestFlight release archives.
  - Coordinates physical hardware testing across wired and wireless CarPlay head-units.

---

## 4. Modern iOS & CarPlay Development Best Practices

Based on Apple Developer Documentation, WWDC sessions (WWDC22 *“Design high-quality CarPlay apps”*, WWDC23 *“Create modern CarPlay apps with SwiftUI”*, WWDC24 *“Explore CarPlay advancements”*), and top iOS engineering standards:

### 1. Declarative Project Specification (XcodeGen / Tuist)
- **Problem:** Teams of developers or AI agents modifying Xcode projects inevitably encounter massive merge conflicts inside `project.pbxproj`.
- **Best Practice:** The entire project structure is declared in `project.yml`. Any file addition or build setting change is committed as clean YAML, followed by `xcodegen generate`.

### 2. Native CarPlay Scene Manifest & Secondary Display Architecture
- **CarPlay Scenes:** CarPlay apps must declare a `UIApplicationSceneManifest` with `CPTemplateApplicationSceneSessionRoleApplication` (`CarPlaySceneDelegate.swift`) and `CPTemplateApplicationDashboardSceneSessionRoleApplication` (`CarPlayDashboardSceneDelegate.swift`).
- **Head-Unit Visibility:** Declaring these delegates ensures DashCast appears directly as an installed app on the vehicle's in-dash home grid.
- **Parked Video Playback:** For video casting, DashCast establishes a secondary UIWindow on the external display screen (`UIScreen.screens` or `UIWindowScene`), rendering high-bitrate video via `AVPlayerLayer` while the vehicle is stationary.

### 3. CoreLocation & CoreMotion Battery Optimization
- Use `CLLocationManager.deferredLocationUpdates` and `CLActivityType.automotiveNavigation` to ensure the GPS hardware uses automotive Kalman filtering.
- Monitor speed thresholds (`> 5 km/h`) with minimal CPU overhead, waking the telemetry engine only when motion is confirmed via `CMMotionActivityManager`.

### 4. Pure SwiftUI Floating Navigation (`LiquidCapsuleTabBar`)
- Replaces UIKit's `UITabBarController` to eliminate dropped touch events and tab state desynchronization in iOS 17/18.
- Utilizes `.safeAreaInset(edge: .bottom)` and haptic feedback (`UIImpactFeedbackGenerator(style: .medium)`) for an ultra-responsive native feel.

---

## 5. Connectors, MCPs & Skills Ecosystem

To empower the autonomous Paperclip team with complete capabilities, the following connectors and MCPs are integrated via **1MCP Hub** (`http://100.66.253.3:3050/mcp`):

| Category | Tool / Connector | Protocol / Endpoint | Purpose & Capabilities |
| :--- | :--- | :--- | :--- |
| **Governance** | **PACA MCP** | `http://100.66.253.3:8080` | Issue tracking, task status (`Todo`, `In Progress`, `In Review`, `Done`), sprint management, team assignments. |
| **Governance** | **Paperclip MCP** | `http://100.66.253.3:3100/api` | Agent company operations, issue checkout (`paperclipCheckoutIssue`), approval requests (`paperclipCreateApproval`), document storage. |
| **Central Hub** | **1MCP Hub** | `http://100.66.253.3:3050/mcp` | Central gateway aggregating all specialized development MCPs into a single authenticated connection. |
| **Source Code** | **GitHub MCP** | `tools.github.*` | Automated Pull Request creation, commit tagging, issue linking, and code review comments. |
| **Documentation** | **Context7 MCP** | `https://mcp.context7.com/mcp` | Real-time Apple Developer Documentation, iOS 17/18 SDK APIs, WWDC session code samples. |
| **App Store CI** | **App Store Connect MCP** | Fastlane / ASC API | Automated TestFlight builds upload, tester group invitations, App Store metadata publishing. |
| **Local Harness** | **Xcodebuild & Simctl MCP** | Local macOS CLI | Running test suites, compiler diagnostics, capturing simulator screenshots for PR verification. |

### Specialized Agent Skills to Employ
1. **`orchestration`**: Coordinates worker agents in parallel, handles heartbeats, task DAGs, and decision gates.
2. **`fastlane-skill`**: Automates `match` certificates, `gym` compilation, and `pilot` TestFlight distribution.
3. **`competitor-scraper`**: Regularly extracts App Store reviews, ratings, and feature updates of rival apps.
4. **`docs` / `docx`**: Generates formatted executive reports, release notes, and marketing one-pagers for stakeholders.

---

## 6. Continuous Competitor Reverse-Engineering ("Keep, Kill, Disrupt")

To establish market dominance, DashCast follows a systematic product strategy against competitors:

| Competitor Feature | Strategy | DashCast Implementation |
| :--- | :---: | :--- |
| **Recurring Subscriptions ($9.99/mo)** | ❌ **KILL** | **Disruption:** Single $19.99 Lifetime Pass. Pay once, own forever. Eliminates subscription fatigue. |
| **Intrusive First-Launch Paywall** | ❌ **KILL** | Full exploratory access to all 5 tabs (`Cast`, `Drive`, `Widgets`, `Sounds`, `Me`). Paywall is presented as an upgrade, never a hostage gate. |
| **4-Row Cast Menu & Source Browser** | ✅ **KEEP** | 1:1 match with Media Source, Local Videos, Mirroring, and 20 streaming source links. |
| **CarPlay Startup & Shutdown Audio** | ✅ **KEEP** | Comprehensive soundboard with engine revs, turbo spools, sci-fi chimes, and 1-tap iOS Shortcuts setup. |
| **License Plate & Car Customization** | ⚡ **DISRUPT** | High-definition stamped metal plate text, 6 curated color swatches, 5 typography options, and real-time in-dash simulator preview. |
| **Low-Framerate Screen Mirroring** | ⚡ **DISRUPT** | Direct `AVPlayerLayer` rendering to secondary CarPlay display, eliminating compression artifacts and touch latency. |
| **CarPlay Head-Unit App Grid** | ⚡ **DISRUPT** | Native `CPTemplateApplicationSceneDelegate` inclusion so DashCast appears directly on the vehicle's native display menu! |

---

## 7. Sprint Backlog & Release Roadmap

```
Sprint 1 (Done/In Review) ──► Sprint 2 (Active Next) ──► Sprint 3 (Streaming) ──► Sprint 4 (Launch)
Yellow Theme Parity           Dynamic Island &           Embedded Local           Viral Marketing &
CarPlay Native Scene          Background Drive           HTTP Server              Global App Store
```

### Sprint 1: Yellow Parity & Native CarPlay (Status: In Review)
- [x] **DI-13**: MediaToAnalyze Ingestion (32 assets mapped) & 60s viral storyboard script.
- [x] **DI-6**: Electric Yellow (`#FFE600`) theme and floating `LiquidCapsuleTabBar`.
- [x] **DI-7**: 1:1 Cast module, 20 streaming sources, native `CarPlaySceneDelegate.swift`, and in-app emulator.
- [x] **DI-8**: Drive HUD, `DriveTrackingPermissionsSheet.swift`, `DriveSettingsView.swift`, and `DriveNotificationService.swift`.
- [x] **DI-9**: Widgets ecosystem, metal stamped plate text, color swatches, typography, and live sliders.
- [x] **DI-10**: Sounds soundboard, categories, and Shortcuts setup guide.
- [x] **DI-11**: "Me" driver profile, settings, about modal, and 1:1 `FeedbackView.swift`.
- [x] **DI-12**: 14 test suites (40 tests passing), automated signing configured.

### Sprint 2: Dynamic Island & Background Intelligence (Active Milestone)
- [x] **ActivityKit Live Activity Extension (`DashCastLiveActivity` / DI-18 / CARAA-10)**:
  - Live driving stats (speed, dynamic G-force, trip distance, smoothness score) on iPhone Lock Screen and Dynamic Island.
  - "Your CarPlay Your Style" teaser banner matching `Live Activity when Open and in Carplay.jpeg`.
  - Comprehensive 15th test suite `DashCastLiveActivityTests.swift`.
- [ ] **CoreMotion Auto-Detect Drives**:
  - Automatic drive detection (`CMMotionActivityManager.isAutomotive`) to automatically trigger trip recording without tapping Start.
- [ ] **Social Trip Share Cards**:
  - Render high-resolution Instagram Story image cards showing drive route, top speed, and vehicle avatar.

### Sprint 3: Low-Latency In-Car Streaming Server
- [ ] **Local Embedded HTTP/HLS Server (`GCDWebServer` / SwiftNIO)**:
  - Stream local camera roll videos and transcoded streams to the car screen at 1080p 60fps with zero buffering.
- [ ] **Picture-in-Picture (PiP) Video Bridge**:
  - Enable background playback so navigation apps (Google Maps, Waze) can display while DashCast audio continues playing.

### Sprint 4: Viral Marketing, App Store Submission & Launch
- [ ] **Production Video Shoot**:
  - Execute `Promotional-Video-Storyboard.md` inside a modern vehicle cockpit at night.
  - Publish across TikTok, Instagram Reels, and YouTube Shorts.
- [ ] **App Store Connect Submission**:
  - Complete App Store metadata, promotional text, 6.7" and 6.5" screenshots with yellow theme.
  - Request CarPlay entitlements from Apple.
- [ ] **Post-Launch A/B Testing**:
  - Test paywall price points ($14.99 vs $19.99 vs $24.99 Lifetime).
