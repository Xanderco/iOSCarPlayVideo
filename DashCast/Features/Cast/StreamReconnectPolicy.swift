import Foundation
import AVFoundation
import Network
import UIKit

/// Live health state of the active video/audio stream.
public enum StreamHealthState: Equatable, Sendable {
    case idle
    case buffering
    case playing
    case reconnecting(attempt: Int, maxAttempts: Int)
    case failed(String)

    public var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

/// Video aspect gravity options for the in-car player.
public enum VideoAspectMode: String, CaseIterable, Sendable {
    case fit
    case fill

    public var avLayerGravity: AVLayerVideoGravity {
        switch self {
        case .fit: return .resizeAspect
        case .fill: return .resizeAspectFill
        }
    }

    public var systemImageName: String {
        switch self {
        case .fit: return "arrow.up.left.and.arrow.down.right"
        case .fill: return "arrow.down.right.and.arrow.up.left"
        }
    }

    public var title: String {
        switch self {
        case .fit: return "Fit"
        case .fill: return "Fill"
        }
    }

    public func toggled() -> VideoAspectMode {
        self == .fit ? .fill : .fit
    }
}

/// Bounded exponential-backoff policy for recovering dropped or stalled streams.
public struct StreamReconnectPolicy: Equatable, Sendable {
    nonisolated public static let `default` = StreamReconnectPolicy()

    public let maxAttempts: Int
    public let baseDelaySeconds: TimeInterval
    public let maxDelaySeconds: TimeInterval
    public let stallGraceSeconds: TimeInterval

    public init(
        maxAttempts: Int = 3,
        baseDelaySeconds: TimeInterval = 1.0,
        maxDelaySeconds: TimeInterval = 8.0,
        stallGraceSeconds: TimeInterval = 4.0
    ) {
        self.maxAttempts = max(0, maxAttempts)
        self.baseDelaySeconds = max(0.05, baseDelaySeconds)
        self.maxDelaySeconds = max(self.baseDelaySeconds, maxDelaySeconds)
        self.stallGraceSeconds = max(0.05, stallGraceSeconds)
    }

    /// Exponential backoff delay (e.g. 1s, 2s, 4s) for 1-based retry attempts.
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponent = Double(max(0, attempt - 1))
        return min(maxDelaySeconds, baseDelaySeconds * pow(2.0, exponent))
    }

    /// Only remote streams (not local files or the local CarPlay mirror loop) should auto-reconnect.
    public func shouldAutoReconnect(
        for channel: ChannelModel?,
        attempt: Int,
        isNetworkAvailable: Bool
    ) -> Bool {
        guard let channel else { return false }
        guard !channel.streamURL.isFileURL else { return false }
        guard channel.id != CarPlayMirrorPlayback.channelID else { return false }
        guard isNetworkAvailable else { return false }
        return attempt < maxAttempts
    }

    /// Distinguishes transient network/transport dropouts from permanent URL/format errors.
    public static func isTransientNetworkError(_ error: Error) -> Bool {
        let ns = error as NSError
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError,
           isTransientNSError(underlying) {
            return true
        }
        return isTransientNSError(ns)
    }

    private static func isTransientNSError(_ ns: NSError) -> Bool {
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case URLError.timedOut.rawValue,
                 URLError.cannotFindHost.rawValue,
                 URLError.cannotConnectToHost.rawValue,
                 URLError.networkConnectionLost.rawValue,
                 URLError.dnsLookupFailed.rawValue,
                 URLError.notConnectedToInternet.rawValue,
                 URLError.internationalRoamingOff.rawValue,
                 URLError.callIsActive.rawValue,
                 URLError.dataNotAllowed.rawValue,
                 URLError.resourceUnavailable.rawValue:
                return true
            case URLError.badURL.rawValue,
                 URLError.unsupportedURL.rawValue,
                 URLError.cancelled.rawValue:
                return false
            default:
                return false
            }
        }
        // AVFoundation / CoreMedia transient network or stream interruption codes
        if ns.domain == AVFoundationErrorDomain {
            return ns.code == AVError.serverIncorrectlyConfigured.rawValue
                || ns.code == AVError.mediaServicesWereReset.rawValue
        }
        return false
    }
}

/// Abstracts `UIApplication.shared.isIdleTimerDisabled` so keep-awake logic is unit-testable.
@MainActor
public protocol IdleTimerControlling: AnyObject {
    var isIdleTimerDisabled: Bool { get set }
}

@MainActor
public final class UIApplicationIdleTimerController: IdleTimerControlling {
    public static let shared = UIApplicationIdleTimerController()
    private init() {}

    public var isIdleTimerDisabled: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
}

/// Abstracts `NWPathMonitor` so network drop/recovery behavior can be tested deterministically.
public protocol NetworkPathMonitoring: AnyObject {
    var isConnected: Bool { get }
    var onStatusChange: (@Sendable (Bool) -> Void)? { get set }
    func start()
    func stop()
}

public final class NoopNetworkPathMonitor: NetworkPathMonitoring {
    public var isConnected: Bool
    public var onStatusChange: (@Sendable (Bool) -> Void)?

    public init(isConnected: Bool = true) {
        self.isConnected = isConnected
    }

    public func start() {}
    public func stop() {}
}

public final class SystemNetworkPathMonitor: NetworkPathMonitoring {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.xanderco.dashcast.network-monitor", qos: .utility)
    private let lock = NSLock()
    private var _isConnected: Bool = true
    private var _onStatusChange: (@Sendable (Bool) -> Void)?

    public init() {}

    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    public var onStatusChange: (@Sendable (Bool) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onStatusChange
        }
        set {
            lock.lock()
            _onStatusChange = newValue
            lock.unlock()
        }
    }

    public func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            self.lock.lock()
            let changed = self._isConnected != satisfied
            self._isConnected = satisfied
            let callback = self._onStatusChange
            self.lock.unlock()
            if changed {
                callback?(satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        monitor.cancel()
    }
}
