import XCTest
@testable import DashCast

final class EVSuperchargerWidgetTests: XCTestCase {

    func testStationPresetsInitialization() {
        let presets = EVStationPreset.allCases
        XCTAssertEqual(presets.count, 4)

        let tesla = EVStationPreset.teslaSupercharger
        XCTAssertEqual(tesla.name, "Tesla Supercharger")
        XCTAssertEqual(tesla.shortName, "Supercharger")
        XCTAssertEqual(tesla.defaultPowerKw, 250.0)
        XCTAssertEqual(tesla.brandColorHex, "#E82127")
        XCTAssertEqual(tesla.systemImage, "bolt.car.fill")
        XCTAssertFalse(tesla.isRestArea)

        let ea = EVStationPreset.electrifyAmerica
        XCTAssertEqual(ea.name, "Electrify America")
        XCTAssertEqual(ea.shortName, "Electrify Am.")
        XCTAssertEqual(ea.defaultPowerKw, 350.0)
        XCTAssertEqual(ea.brandColorHex, "#00B140")
        XCTAssertEqual(ea.systemImage, "bolt.batteryblock.fill")
        XCTAssertFalse(ea.isRestArea)

        let evgo = EVStationPreset.evgo
        XCTAssertEqual(evgo.name, "EVgo Fast Charging")
        XCTAssertEqual(evgo.shortName, "EVgo")
        XCTAssertEqual(evgo.defaultPowerKw, 150.0)
        XCTAssertEqual(evgo.brandColorHex, "#0057B8")
        XCTAssertEqual(evgo.systemImage, "powerplug.fill")
        XCTAssertFalse(evgo.isRestArea)

        let restArea = EVStationPreset.restArea
        XCTAssertEqual(restArea.name, "Rest Area & Coffee Break")
        XCTAssertEqual(restArea.shortName, "Rest Stop")
        XCTAssertEqual(restArea.defaultPowerKw, 0.0)
        XCTAssertEqual(restArea.brandColorHex, "#FFB800")
        XCTAssertEqual(restArea.systemImage, "cup.and.saucer.fill")
        XCTAssertTrue(restArea.isRestArea)
    }

    func testChargingDurationCalculations() {
        let tesla = EVStationPreset.teslaSupercharger

        // 20% to 80% on 250 kW: 60% delta on 75 kWh battery
        let minutes = tesla.estimatedMinutes(startPct: 20.0, targetPct: 80.0, batteryCapacityKWh: 75.0)
        XCTAssertGreaterThan(minutes, 5.0)
        XCTAssertLessThan(minutes, 35.0)

        // When target <= start, should return 0 minutes
        let zeroMinutes = tesla.estimatedMinutes(startPct: 80.0, targetPct: 80.0)
        XCTAssertEqual(zeroMinutes, 0.0)

        let negativeMinutes = tesla.estimatedMinutes(startPct: 90.0, targetPct: 70.0)
        XCTAssertEqual(negativeMinutes, 0.0)

        // Taper check: 80% to 100% (20% delta) should take more time per percentage point than 20% to 40% (20% delta)
        let fastDeltaMinutes = tesla.estimatedMinutes(startPct: 20.0, targetPct: 40.0, batteryCapacityKWh: 75.0)
        let taperDeltaMinutes = tesla.estimatedMinutes(startPct: 80.0, targetPct: 100.0, batteryCapacityKWh: 75.0)
        XCTAssertGreaterThan(taperDeltaMinutes, fastDeltaMinutes, "Charging above 80% should taper and take longer than below 80%")

        // Comparison: 350 kW Electrify America should be faster than 150 kW EVgo for the same charge
        let eaMinutes = EVStationPreset.electrifyAmerica.estimatedMinutes(startPct: 20.0, targetPct: 80.0)
        let evgoMinutes = EVStationPreset.evgo.estimatedMinutes(startPct: 20.0, targetPct: 80.0)
        XCTAssertLessThan(eaMinutes, evgoMinutes)
    }

    func testRestStopPresetDuration() {
        let restArea = EVStationPreset.restArea
        XCTAssertEqual(restArea.estimatedMinutes(startPct: 0, targetPct: 100), 20.0)
    }

    @MainActor
    func testSessionManagerStartAndStop() {
        let manager = EVChargingSessionManager()
        manager.selectPreset(.teslaSupercharger)
        manager.setStartBattery(20.0)
        manager.setTargetBattery(80.0)

        XCTAssertFalse(manager.isSessionActive)
        XCTAssertNil(manager.sessionStartTime)
        XCTAssertNil(manager.estimatedCompletionTime)

        manager.startSession()

        XCTAssertTrue(manager.isSessionActive)
        XCTAssertNotNil(manager.sessionStartTime)
        XCTAssertNotNil(manager.estimatedCompletionTime)
        XCTAssertEqual(manager.currentBatteryPercentage, 20.0)
        XCTAssertGreaterThan(manager.estimatedCompletionTime!, manager.sessionStartTime!)

        manager.stopSession()

        XCTAssertFalse(manager.isSessionActive)
        XCTAssertNil(manager.sessionStartTime)
        XCTAssertNil(manager.estimatedCompletionTime)
    }

    @MainActor
    func testSessionManagerPresetSelection() {
        let manager = EVChargingSessionManager()
        manager.selectPreset(.electrifyAmerica)
        XCTAssertEqual(manager.activePreset, .electrifyAmerica)
        XCTAssertEqual(manager.chargePowerKw, 350.0)

        manager.selectPreset(.restArea)
        XCTAssertEqual(manager.activePreset, .restArea)
        XCTAssertTrue(manager.activePreset.isRestArea)
    }

    @MainActor
    func testBatteryClamping() {
        let manager = EVChargingSessionManager()

        // Clamp below 0
        manager.setStartBattery(-10.0)
        XCTAssertEqual(manager.startBatteryPercentage, 0.0)

        // Clamp above 100
        manager.setStartBattery(120.0)
        XCTAssertEqual(manager.startBatteryPercentage, 100.0)

        // Target cannot be below start
        manager.setStartBattery(60.0)
        manager.setTargetBattery(40.0)
        XCTAssertGreaterThanOrEqual(manager.targetBatteryPercentage, manager.startBatteryPercentage)
    }

    @MainActor
    func testSimulationTickProgress() {
        let manager = EVChargingSessionManager()
        manager.selectPreset(.teslaSupercharger)
        manager.setStartBattery(20.0)
        manager.setTargetBattery(80.0)
        manager.startSession()

        let initialBattery = manager.currentBatteryPercentage
        let initialEnergy = manager.energyDeliveredKWh

        // Tick 300 seconds (5 minutes of 250 kW charging)
        manager.tickSimulation(elapsedSeconds: 300.0)

        XCTAssertGreaterThan(manager.currentBatteryPercentage, initialBattery)
        XCTAssertGreaterThan(manager.energyDeliveredKWh, initialEnergy)
        XCTAssertLessThanOrEqual(manager.currentBatteryPercentage, 80.0)

        manager.stopSession()
    }

    func testWidgetSharedPayloadEVChargingRoundtrip() throws {
        let snapshot = SharedEVChargingSnapshot(
            stationName: "Tesla Supercharger",
            stationPresetRaw: "teslaSupercharger",
            currentBattery: 54,
            targetBattery: 80,
            powerKw: 250.0,
            isCharging: true,
            isRestArea: false,
            startTime: Date(timeIntervalSince1970: 1_793_000_000),
            targetCompletionTime: Date(timeIntervalSince1970: 1_793_001_200),
            restStopDurationMinutes: 20,
            notes: "V3 250 kW"
        )

        let payload = WidgetSharedPayload(
            evSession: snapshot,
            usesMiles: true,
            updatedAt: Date(timeIntervalSince1970: 1_793_000_100)
        )

        let encoded = try WidgetSharedStore.encode(payload)
        let decoded = try WidgetSharedStore.decode(encoded)

        XCTAssertNotNil(decoded.evSession)
        XCTAssertEqual(decoded.evSession, snapshot)
        XCTAssertEqual(decoded.evSession?.stationName, "Tesla Supercharger")
        XCTAssertEqual(decoded.evSession?.currentBattery, 54)
        XCTAssertEqual(decoded.evSession?.targetBattery, 80)
        XCTAssertEqual(decoded.evSession?.powerKw, 250.0)
        XCTAssertTrue(decoded.evSession?.isCharging ?? false)
        XCTAssertFalse(decoded.evSession?.isRestArea ?? true)
    }

    func testDeepLinkDestinations() {
        let superchargerURL = URL(string: "dashcast://supercharger")!
        XCTAssertEqual(DashCastLinks.destination(for: superchargerURL), .supercharger)

        let castURL = URL(string: "dashcast://cast")!
        XCTAssertEqual(DashCastLinks.destination(for: castURL), .cast)

        let driveURL = URL(string: "dashcast://drive")!
        XCTAssertEqual(DashCastLinks.destination(for: driveURL), .drive)
    }

    @MainActor
    func testAppStateDeepLinkHandling() {
        let appState = AppState.shared
        appState.handleDeepLink(URL(string: "dashcast://supercharger")!)
        XCTAssertEqual(appState.selectedTab, .widgets)

        appState.handleDeepLink(URL(string: "dashcast://cast")!)
        XCTAssertEqual(appState.selectedTab, .cast)
    }

    func testActivityAttributesContentState() {
        let state = EVChargingActivityAttributes.ContentState(
            stationName: "Electrify America",
            stationPresetRaw: "electrifyAmerica",
            currentBattery: 35,
            targetBattery: 80,
            powerKw: 350.0,
            isCharging: true,
            isRestArea: false,
            startTime: Date(timeIntervalSince1970: 1_793_000_000),
            estimatedCompletionTime: Date(timeIntervalSince1970: 1_793_001_500),
            statusText: "Hyper-Fast 350 kW"
        )

        XCTAssertEqual(state.stationName, "Electrify America")
        XCTAssertEqual(state.currentBattery, 35)
        XCTAssertEqual(state.powerKw, 350.0)
        XCTAssertFalse(state.isRestArea)
        XCTAssertEqual(state.statusText, "Hyper-Fast 350 kW")

        let attributes = EVChargingActivityAttributes(sessionTitle: "Electrify America")
        XCTAssertEqual(attributes.sessionTitle, "Electrify America")
    }
}
