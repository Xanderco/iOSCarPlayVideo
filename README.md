# DashCast 🚗💨

> **The Ultimate Parked Video, Drive Telemetry, Territory Conquest & In-Car Sound Experience.**  
> *Pay Once. Own Forever. Zero Subscriptions.*

A modern, high-performance iOS application designed for in-car enthusiasts and CarPlay owners. DashCast provides all the premium capabilities of subscription-based apps like CarDash, but with a transparent **one-time purchase** lifetime model.

---

## 🌟 Core Features

### 1. 📺 Cast & Video Player (For Parked Break / EV Charging)
- **IPTV / M3U Stream Engine**: Parse any personal M3U / M3U8 streaming playlist with category tagging (Movies, Live, Sports, News).
- **Secondary Car Display Output**: Automatically detects external screens (CarPlay head units, AirPlay, HDMI, CarlinKit adapters) and renders dedicated video playback on the car display while retaining driver controls on iPhone.
- **In-App Web Video Browser**: Integrated `WKWebView` with URL search bar and quick bookmarks (YouTube, Vimeo, Twitch).
- **Local Video Importer**: Import your own video files from Apple Photos or Files app into the car playlist.
- **Screen Broadcast Mirroring**: System-level `RPSystemBroadcastPickerView` integration.
- **Automotive Safety Notice**: Clear parked-only safety disclosure.

### 2. ⚡ Drive Telemetry & Smoothness Scoring
- **Speedometer HUD**: Circular neon speedometer gauge with instant toggle between `KM/H` and `MPH`.
- **Live Metrics**: Distance, Duration, Altitude, Average Speed, Top Speed, and Idle Stop Duration.
- **Speed-Gradient Route Map**: Dark-mode MapKit rendering GPS route polylines color-coded by driving speed (Red = slow/traffic, Orange = moderate, Green = cruise, Blue = highway).
- **Smoothness Scoring (0–100)**: Real-time accelerometer telemetry analyzing harsh braking (>0.35g), aggressive acceleration (>0.30g), and sharp cornering (>0.45g).
- **Trip History & Summary**: Detailed route review with driving score breakdown.

### 3. 🔷 Claim Your Streets (Territory Hex Map)
- **Hexagonal Spatial Grid Engine**: Pure Swift discrete hexagonal spatial indexer (`HexGridEngine`).
- **Territory Conquest**: Every driven street unlocks glowing neon-cyan hexagonal map cells.
- **Driver Ranks**: Climb from *Rookie Driver* ➔ *Street Cruiser* ➔ *Road Captain* ➔ *Road King* ➔ *Highway Legend*.
- **Territory Metrics**: Total hexes claimed, weekly addition counter, and square miles/kilometers conquered.

### 4. 🎨 CarPlay Dashboard Widgets & Live Wallpapers
- **100+ Automotive Brands**: Toyota, Chevrolet, Ford, Porsche, BMW, Mercedes-Benz, Audi, Tesla, Jeep, Ferrari, etc.
- **Live CarPlay Mockup**: Realistic in-car dashboard simulator previewing dual widgets and CarPlay sidebar.
- **Widget Editor**: Customize vehicle models, brand watermarks, driver greetings ("Welcome, Driver"), and sticker badges (Route 66, Checkered Flag, Turbo).
- **3.0-Second Live Video Trimmer**: Interactive loop trimmer for animated live wallpapers.

### 5. 🔊 Car Personality Sounds & Siri Shortcuts
- **100+ Automotive Soundboard**: Curated sound effects across 6 categories (Voices, Engine revs, Futuristic warp pulses, Chimes, Cinematic drops).
- **Active Trigger Slots**: Assign custom sounds for **CarPlay Connection**, **Disconnection**, and **Home Arrival**.
- **Tone Synthesizer Engine**: `AVAudioEngine` real-time acoustic tone synthesizer.
- **Siri Shortcuts Automation Guide**: Interactive step-by-step tutorial to configure automatic triggers in iOS Shortcuts.

### 6. 💎 Pay Once · Own Forever (StoreKit 2)
- **No Monthly Fees**: Replaces predatory $4.99/month ($60/year) subscription models with a single **$19.99 Lifetime Pass** (`com.dashcast.lifetime`).
- **StoreKit 2 Concurrency**: Built on Apple's modern Swift Concurrency StoreKit 2 APIs.
- **Offline Entitlement Caching**: Unlocks features even when out of cellular coverage on remote roads.
- **Local Testing**: Includes `DashCastStore.storekit` configuration file for offline testing in Xcode and the Simulator.

---

## 🛠 Tech Stack

- **Target**: iOS 17.0+
- **Language**: Swift 5.9 / Swift 6
- **UI**: SwiftUI (Deep Black & Neon Automotive Design System)
- **Audio & Video**: `AVFoundation`, `AVKit`, `WebKit`, `ReplayKit`
- **Sensors & Maps**: `CoreLocation`, `CoreMotion`, `MapKit`
- **Spatial Indexing**: Flat-Topped Hexagonal Spatial Grid (`HexGridEngine`)
- **Persistence**: `PersistenceController` with Swift Codable & App Group support
- **In-App Purchase**: StoreKit 2 (`StoreKitManager`)
- **Project Generation**: `XcodeGen` (`project.yml`)
- **Testing**: `XCTest` suite (Unit, Integration, and End-to-End)

---

## 🚀 Getting Started

### Prerequisites
- macOS Sonoma or Sequoia
- Xcode 15 or Xcode 16+ (tested on Xcode 27.2)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build & Run Tests
```bash
# 1. Clone repository
git clone https://github.com/Xanderco/iOSCarPlayVideo.git
cd iOSCarPlayVideo

# 2. Run the automated test suite
./Scripts/run-tests.sh

# 3. Build for iOS Simulator
./Scripts/build.sh
```

Or open directly in Xcode:
```bash
xcodegen generate
open DashCast.xcodeproj
```

---

## 🧪 Automated Testing Suite

DashCast contains a comprehensive unit and integration test suite with **100% pass rate** on the iOS Simulator:

- `AppStateTests`: State management, tab selection, and lifetime entitlement transitions.
- `StoreKitTests`: StoreKit 2 identifiers, cached offline entitlements, and error states.
- `CastEngineTests`: IPTV M3U parser, multi-attribute parsing, category tagging, and playlist integrity.
- `DriveTelemetryTests`: Driving scoring penalties, floor boundaries, and simulated GPS location points.
- `TerritoryEngineTests`: Hexagonal coordinate math, 6-vertex polygon geometry, driver ranks, and area calculations.
- `WidgetCatalogTests`: Automotive catalog, brand filtering, sticker inventory, and widget persistence.
- `SoundEngineTests`: Soundboard inventory, category filters, and preference serialization.
- `EndToEndFlowTests`: Complete user lifecycle (Fresh launch ➔ Lifetime unlock ➔ Drive tracking ➔ Trip score ➔ Territory claim ➔ Widget customization ➔ Sound assignment).

---

## 📄 License
Proprietary software for DashCast. All rights reserved.
