# DashCast Inc. 🚗💨 — Master Company System Document & Agent Operating Manual

**Company Name:** CarDash / DashCast Inc.  
**Company Slug / Issue Prefix:** `CARAA`  
**Paperclip Dashboard:** `http://100.66.253.3:3100/CARAA/dashboard`  
**PACA Project UUID:** `250c3694-30fa-414d-a9ec-aa541d659ad9` (`http://100.66.253.3:8080`)  
**Repository:** `Xanderco/iOSCarPlayVideo`  
**Active Branch:** `feat/cardash-yellow-redesign`  
**Human Owner & Sole Approval Authority:** Alexander Benitez  
**Business Model:** Lifetime Access ($19.99 One-Time) — Zero Recurring Subscriptions

---

## 📌 MANDATORY NOTICE TO ALL AUTONOMOUS AGENTS
**READ THIS DOCUMENT BEFORE UNDERTAKING ANY TASK.**  
Every agent spawned by Paperclip or PACA must execute within the constraints, conventions, and governance gates established herein. Non-compliant work will fail the human review gate.

---

## 1. Company Mission, Vision & Market Disruption

### The Core Problem in the Market
Car enthusiasts, commuters, and EV drivers spend hours in parked vehicles (charging, waiting, resting) and desire:
1. In-dash personalized dashboard widgets (analog tachometer clocks, license plates, countdowns, vinyl records).
2. Custom vehicle startup and shutdown audio triggered automatically via Apple CarPlay connection.
3. High-definition video casting (YouTube, IPTV, Netflix, local phone videos) onto the vehicle head-unit.

Competitors like **CarDash**, **CarTV (@cartv_cast2car)**, and **PlayCar** charge **predatory recurring subscriptions ($9.99/month or $4.99/month)**, block first-time users behind aggressive instant paywalls, and suffer from high-latency screen mirroring that drops frames.

### The DashCast Disruption
1. **$19.99 Lifetime Pass:** Pay once. Own forever. Zero monthly fees.
2. **Native CarPlay Grid & Dashboard Presence:** Configured via `CPTemplateApplicationSceneDelegate` (`CarPlaySceneDelegate.swift`), making DashCast a real, clickable app in the car's native dashboard grid.
3. **1:1 Yellow Racing Automotive Theme:** Electric Yellow (`#FFE600`), Racing Gold (`#FFB800`), and OLED True Deep Black (`#0C0D10`) with tactile floating `LiquidCapsuleTabBar`.
4. **100% Automated Testing:** Zero regressions accepted across 14 test suites and 40 unit/integration tests.

---

## 2. Autonomous Agent Architecture ("The Hires")

```
                       ┌───────────────────────────────┐
                       │       Alexander Benitez       │
                       │   (Human Owner & Gatekeeper)  │
                       └───────────────┬───────────────┘
                                       │ Approves "In Review" ➔ "Done"
                       ┌───────────────▼───────────────┐
                       │   @dashcast-orchestrator      │
                       │   (CEO & Operational Director)│
                       └───────────────┬───────────────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         │                             │                             │
┌────────▼────────────┐      ┌─────────▼──────────┐       ┌──────────▼──────────┐
│ @dashcast-ios-lead  │      │ @dashcast-scout    │       │ @dashcast-designer  │
│ (CTO / Swift Lead)  │      │ (Competitor Intel) │       │ (UX & Ergonomics)   │
└────────┬────────────┘      └────────────────────┘       └─────────────────────┘
         │
┌────────▼────────────┐
│ @dashcast-qa-deploy │
│ (QA & Release Eng)  │
└─────────────────────┘
```

---

## 3. Correct OpenCode Adapter Configuration (Validated on SVR / Windows Host)

To ensure agents in Paperclip run reliably without executable lookup or model format errors (replicating the verified configuration of `LaGuaca.online`), all agents must use these adapter parameters:

```json
{
  "adapterType": "opencode_local",
  "adapterConfig": {
    "command": "C:\\Program Files\\nodejs\\node_modules\\@opencode\\cli\\bin\\opencode.exe",
    "model": "omniroute/Xander-agents",
    "cwd": "C:\\Users\\benit\\Repos\\iOSCarPlayVideo",
    "timeoutSec": 2400,
    "graceSec": 15,
    "dangerouslySkipPermissions": true,
    "runPolicy": {
      "heartbeatIntervalSec": 43200
    },
    "env": {
      "PACA_API_URL": "http://100.66.253.3:8080",
      "PACA_API_KEY": "paca_2803e45267d5391beed96c25a1df7cc415fa7a5609bc7456204710cdedfbf504",
      "PAPERCLIP_API_URL": "http://100.66.253.3:3100"
    }
  }
}
```

*Note on Models:*
- **CEO & Lead iOS**: `omniroute/Xander-agents` (or `omniroute/Xander-code`)
- **Scout / Growth**: `omniroute/Xander-fast` (optimized for fast scraping and text analysis)

---

## 4. Mandatory Reading Matrix per Agent

Every agent is required to read specific project documents based on their operational department:

| Agent Role | Mandatory Reading Material | Key Takeaway / Focus Area |
| :--- | :--- | :--- |
| **CEO (`@dashcast-orchestrator`)** | `Docs/Paperclip/PAPERCLIP_COMPANY_SYSTEM_DOCUMENT.md`<br>`PROGRESS.md`<br>`PAPERCLIP.md` | Strategic governance, task decomposition, PACA/Paperclip synchronization, enforcement of the Alexander Gate. |
| **CTO & iOS Lead (`@dashcast-ios-lead`)** | `Docs/Paperclip/PAPERCLIP_COMPANY_SYSTEM_DOCUMENT.md`<br>`DashCast/CarPlay/CarPlaySceneDelegate.swift`<br>`DashCast/Features/Drive/DriveLocationService.swift`<br>`DashCast/Features/Cast/VideoPlayerService.swift` | Swift 5.9, AVFoundation, CPTemplateApplicationSceneDelegate, StoreKit 2 Lifetime, CoreLocation battery optimization. |
| **Growth & Scout (`@dashcast-scout`)** | `Docs/Marketing/MediaToAnalyze-Mapping.md`<br>`Docs/Marketing/Promotional-Video-Storyboard.md` | 32 reference media assets, competitor video deconstruction (@cartv_cast2car), viral TikTok scripts, ASO keywords. |
| **UX & Ergonomics (`@dashcast-designer`)** | `MediaToAnalyze/`<br>`DashCast/Features/Widgets/WidgetEditorView.swift`<br>`DashCast/Features/Cast/CarPlaySimulatorView.swift`<br>`DashCast/Core/DesignSystem/ThemeColors.swift` | Electric Yellow `#FFE600`, OLED True Black `#0C0D10`, metal stamped license plates, 48pt touch targets, in-dash emulator fidelity. |
| **QA & Release Eng (`@dashcast-qa-deploy`)** | `project.yml`<br>`DashCastTests/`<br>`PROGRESS.md` | XcodeGen generation, zero merge conflicts, 14 test suites (40 tests passing 100%), automatic signing with Team `96YG38576A`. |

---

## 5. The 5-Phase End-to-End Execution Protocol

```
[Phase 1: Intake & Diff] ➔ [Phase 2: PACA Pre-Flight] ➔ [Phase 3: Implementation] ➔ [Phase 4: Automated Testing] ➔ [Phase 5: Human Gate]
```

1. **Phase 1: Intake & Competitor Diff**:
   - The Scout analyzes new media or competitor App Store updates and details: *What is new? How does it look? What is the competitor's flaw?*
2. **Phase 2: PACA & Paperclip Pre-Flight**:
   - Query PACA (`http://100.66.253.3:8080`) and Paperclip (`http://100.66.253.3:3100`).
   - Move task to **In Progress**.
   - Create a dedicated worktree branch: `feature/<TASK_ID>-<slug>` (never touch `main`).
3. **Phase 3: Clean Implementation**:
   - Pure SwiftUI navigation (`LiquidCapsuleTabBar`) avoiding UIKit gesture drops.
   - Singleton service architecture (`VehicleCatalogService`, `SoundCatalogService`, `DriveLocationService`).
   - Run `xcodegen generate` if project structure changes.
4. **Phase 4: Automated Verification**:
   - Write dedicated unit tests in `DashCastTests/`.
   - Run `xcodebuild test -project DashCast.xcodeproj -scheme DashCast -destination 'platform=iOS Simulator,name=iPhone 17'`.
   - 100% pass rate required. Zero failures allowed.
5. **Phase 5: Deliverable Report & Human Gate**:
   - Commit with Conventional Commits format (`feat(...)`, `fix(...)`, `docs(...)`).
   - Push branch to GitHub.
   - Update PACA and Paperclip task description with Deliverable Report: *Repository, Branch, Commit SHA, Test Proof*.
   - Move task to **In Review**.
   - **Alexander Gate:** Only Alexander Benitez has the authority to approve to **Done**.

---

## 6. Competitor Reverse-Engineering Engine ("Keep, Kill, Disrupt")

- **KILL**: Predatory recurring subscriptions ($9.99/mo), aggressive launch paywalls, low-framerate screen mirroring.
- **KEEP**: 4-row Cast menu card, 20 streaming source browser, custom startup soundboard, widget presets.
- **DISRUPT**: $19.99 Lifetime Unlock, native CarPlay scene on vehicle grid, metal plate stamped customizer, high-contrast OLED yellow theme.

---

## 7. Sprint Backlog & Release Roadmap

### Sprint 1: Yellow Parity & Native CarPlay (Status: In Review)
- All 8 activities (DI-13 to DI-12) completed, verified, and synchronized in PACA and Paperclip.

### Sprint 2: Dynamic Island & Background Drive Intelligence (Active Milestone)
- **ActivityKit Live Activity Extension (`DashCastLiveActivity`)**: Live speed and telemetry on iPhone Dynamic Island and Lock Screen.
- **CoreMotion Auto-Detect Drives**: Background drive detection via `CMMotionActivityManager.isAutomotive`.
- **Instagram Story Social Share Cards**: Exportable high-resolution graphic cards showing drive telemetry, vehicle badge, and route.

### Sprint 3: Low-Latency In-Car Streaming Server
- **Embedded Local HTTP/HLS Server (`GCDWebServer` / SwiftNIO)**: 1080p 60fps streaming to car display with zero buffering.
- **Picture-in-Picture (PiP) Video Bridge**: Seamless background audio/video playback when switching to navigation.

### Sprint 4: Viral Marketing, App Store Submission & Launch
- **Production Video Shoot**: Record the 60-second video script in `Promotional-Video-Storyboard.md`.
- **App Store Submission**: Deliver TestFlight build, request CarPlay entitlements from Apple, and launch.
