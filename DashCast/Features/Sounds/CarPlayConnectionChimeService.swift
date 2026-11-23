import Foundation
import AVFoundation
import Combine

public enum ConnectionTriggerSource: String, Sendable {
    case carPlayTemplate = "CarPlay Scene"
    case audioRoute = "Audio Route"
}

@MainActor
public final class CarPlayConnectionChimeService: ObservableObject {
    public static let shared = CarPlayConnectionChimeService()

    @Published public private(set) var isConnectedToCar: Bool = false
    @Published public private(set) var lastTriggeredDate: Date?
    @Published public private(set) var lastTriggerSource: ConnectionTriggerSource?

    private var cancellables = Set<AnyCancellable>()
    private var lastConnectionTimestamp: TimeInterval = 0
    private var lastDisconnectionTimestamp: TimeInterval = 0
    private let debounceInterval: TimeInterval = 4.0

    public init() {
        startMonitoring()
    }

    /// Begins monitoring system audio route changes for Bluetooth and CarPlay events.
    public func startMonitoring() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
            .store(in: &cancellables)

        checkCurrentRouteInitialState()
    }

    public func stopMonitoring() {
        cancellables.removeAll()
    }

    // MARK: - CarPlay Delegate Hooks

    /// Invoked directly by `CarPlaySceneDelegate` when CarPlay template connects.
    public func handleCarPlayConnected() {
        isConnectedToCar = true
        triggerConnectionChime(source: .carPlayTemplate)
    }

    /// Invoked directly by `CarPlaySceneDelegate` when CarPlay template disconnects.
    public func handleCarPlayDisconnected() {
        isConnectedToCar = false
        triggerDisconnectionChime(source: .carPlayTemplate)
    }

    // MARK: - Audio Route Detection

    private func checkCurrentRouteInitialState() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let hasCarAudio = outputs.contains { isCarOrBluetoothPort($0.portType) }
        isConnectedToCar = hasCarAudio
    }

    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawReason = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            return
        }

        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let nowConnected = outputs.contains { isCarOrBluetoothPort($0.portType) }

        switch reason {
        case .newDeviceAvailable:
            if nowConnected && !isConnectedToCar {
                isConnectedToCar = true
                triggerConnectionChime(source: .audioRoute)
            }
        case .oldDeviceUnavailable:
            if !nowConnected && isConnectedToCar {
                isConnectedToCar = false
                triggerDisconnectionChime(source: .audioRoute)
            }
        case .categoryChange, .routeConfigurationChange:
            if nowConnected && !isConnectedToCar {
                isConnectedToCar = true
                triggerConnectionChime(source: .audioRoute)
            } else if !nowConnected && isConnectedToCar {
                isConnectedToCar = false
            }
        default:
            break
        }
    }

    private func isCarOrBluetoothPort(_ port: AVAudioSession.Port) -> Bool {
        return port == .carAudio ||
               port == .bluetoothA2DP ||
               port == .bluetoothHFP ||
               port == .bluetoothLE
    }

    // MARK: - Trigger Execution & Debounce

    private func triggerConnectionChime(source: ConnectionTriggerSource) {
        let now = Date().timeIntervalSince1970
        guard (now - lastConnectionTimestamp) > debounceInterval else {
            return
        }

        lastConnectionTimestamp = now
        lastTriggeredDate = Date()
        lastTriggerSource = source

        SoundPlayerEngine.shared.triggerCarPlayConnectionSound()
    }

    private func triggerDisconnectionChime(source: ConnectionTriggerSource) {
        let now = Date().timeIntervalSince1970
        guard (now - lastDisconnectionTimestamp) > debounceInterval else {
            return
        }

        lastDisconnectionTimestamp = now
        lastTriggeredDate = Date()
        lastTriggerSource = source

        SoundPlayerEngine.shared.triggerCarPlayDisconnectionSound()
    }
}
