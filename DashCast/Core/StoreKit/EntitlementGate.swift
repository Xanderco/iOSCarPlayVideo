import Foundation
import Combine

/// The single place that decides what a free user may do.
///
/// Features ask the gate before acting instead of reading `isPro` themselves, so the
/// free-tier rules live in exactly one file:
///
/// ```swift
/// guard EntitlementGate.shared.request(.addPlaylistSource(existingCount: store.playlists.count)) else { return }
/// guard EntitlementGate.shared.request(.startCasting) else { return }
/// EntitlementGate.shared.recordCasting(seconds: elapsed)   // while playing on the car / external screen
/// ```
@MainActor
public final class EntitlementGate: ObservableObject {
    public static let shared = EntitlementGate(
        isProPublisher: StoreKitManager.shared.$entitlement.map(\.isPro).eraseToAnyPublisher(),
        initialIsPro: StoreKitManager.shared.isPro,
        onBlocked: { _ in AppState.shared.showPaywall = true }
    )

    public struct FreeTierLimits: Equatable, Sendable {
        public var maxPlaylistSources: Int
        public var dailyCastingSeconds: TimeInterval

        public init(maxPlaylistSources: Int, dailyCastingSeconds: TimeInterval) {
            self.maxPlaylistSources = maxPlaylistSources
            self.dailyCastingSeconds = dailyCastingSeconds
        }

        public static let standard = FreeTierLimits(maxPlaylistSources: 1, dailyCastingSeconds: 15 * 60)

        public var dailyCastingMinutes: Int { Int(dailyCastingSeconds / 60) }
    }

    public enum Feature: Equatable, Sendable {
        /// Adding a new playlist source (M3U URL or file). Re-importing an existing one is not "adding".
        case addPlaylistSource(existingCount: Int)
        /// Starting playback on the car / external display.
        case startCasting
    }

    public enum Decision: Equatable, Sendable {
        case allowed
        case playlistLimitReached(limit: Int)
        case dailyCastingLimitReached(minutes: Int)

        public var isAllowed: Bool { self == .allowed }

        /// Short, factual explanation shown on the paywall when it was opened by a limit.
        public var message: String? {
            switch self {
            case .allowed:
                return nil
            case .playlistLimitReached(let limit):
                return "The free plan includes \(limit) playlist source\(limit == 1 ? "" : "s")."
            case .dailyCastingLimitReached(let minutes):
                return "You've used today's \(minutes) free casting minutes. They reset at midnight."
            }
        }
    }

    @Published public private(set) var isPro: Bool
    @Published public private(set) var castingSecondsUsedToday: TimeInterval = 0
    /// The most recent block, so the paywall can say why it appeared.
    @Published public private(set) var lastBlock: Decision?

    public let limits: FreeTierLimits

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private let onBlocked: (@MainActor (Decision) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    static let usageKey = "dashcast_free_casting_usage_v1"

    private struct DailyUsage: Codable {
        var day: String
        var seconds: TimeInterval
    }

    public init(isProPublisher: AnyPublisher<Bool, Never>,
                initialIsPro: Bool = false,
                limits: FreeTierLimits = .standard,
                defaults: UserDefaults = .standard,
                calendar: Calendar = .current,
                now: @escaping () -> Date = Date.init,
                onBlocked: (@MainActor (Decision) -> Void)? = nil) {
        self.isPro = initialIsPro
        self.limits = limits
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        self.onBlocked = onBlocked
        self.castingSecondsUsedToday = storedUsageForToday()

        // StoreKitManager publishes on the main actor, so updates are applied synchronously.
        isProPublisher
            .removeDuplicates()
            .sink { [weak self] value in
                MainActor.assumeIsolated {
                    self?.setIsPro(value)
                }
            }
            .store(in: &cancellables)
    }

    /// Test / preview hook to set the Pro flag synchronously.
    func setIsPro(_ value: Bool) {
        if isPro != value { isPro = value }
        if value { lastBlock = nil }
    }

    // MARK: Decisions

    /// Pure check: no side effects.
    public func check(_ feature: Feature) -> Decision {
        if isPro { return .allowed }
        switch feature {
        case .addPlaylistSource(let existingCount):
            return existingCount < limits.maxPlaylistSources
                ? .allowed
                : .playlistLimitReached(limit: limits.maxPlaylistSources)
        case .startCasting:
            return remainingCastingSeconds > 0
                ? .allowed
                : .dailyCastingLimitReached(minutes: limits.dailyCastingMinutes)
        }
    }

    /// Checks the feature and, when blocked, records why and presents the paywall.
    /// Returns `true` when the feature may proceed.
    @discardableResult
    public func request(_ feature: Feature) -> Bool {
        let decision = check(feature)
        if !decision.isAllowed {
            lastBlock = decision
            onBlocked?(decision)
        }
        return decision.isAllowed
    }

    // MARK: Casting minutes

    /// Seconds of casting left today for a free user; `.infinity` for Pro.
    public var remainingCastingSeconds: TimeInterval {
        if isPro { return .infinity }
        return max(0, limits.dailyCastingSeconds - storedUsageForToday())
    }

    /// Minutes of casting left today for a free user; `.max` for Pro.
    public var remainingCastingMinutes: Int {
        if isPro { return .max }
        return Int(ceil(remainingCastingSeconds / 60))
    }

    /// Adds casting time to today's tally. Returns `false` once a free user has run out,
    /// so the player knows to stop; the paywall is presented at that point.
    @discardableResult
    public func recordCasting(seconds: TimeInterval) -> Bool {
        guard !isPro else { return true }
        var used = storedUsageForToday()
        if seconds > 0, seconds.isFinite {
            used = min(limits.dailyCastingSeconds, used + seconds)
            saveUsage(used)
        }
        if castingSecondsUsedToday != used { castingSecondsUsedToday = used }
        if used >= limits.dailyCastingSeconds {
            return request(.startCasting)
        }
        return true
    }

    /// Re-reads today's usage (call when the app returns to the foreground after midnight).
    public func refreshUsage() {
        let used = storedUsageForToday()
        if castingSecondsUsedToday != used { castingSecondsUsedToday = used }
    }

    // MARK: Persistence

    private func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func storedUsageForToday() -> TimeInterval {
        guard let data = defaults.data(forKey: Self.usageKey),
              let usage = try? JSONDecoder().decode(DailyUsage.self, from: data),
              usage.day == dayKey(now()) else { return 0 }
        return usage.seconds
    }

    private func saveUsage(_ seconds: TimeInterval) {
        let usage = DailyUsage(day: dayKey(now()), seconds: seconds)
        if let data = try? JSONEncoder().encode(usage) {
            defaults.set(data, forKey: Self.usageKey)
        }
    }
}
