import Foundation

/// Sleep / parked-session timer presets for the player HUD.
public enum SleepTimerPreset: Int, CaseIterable, Identifiable, Sendable {
    case off = 0
    case fifteen = 15
    case thirty = 30
    case sixty = 60

    public var id: Int { rawValue }

    /// Timer length in seconds, `nil` for `.off`.
    public var duration: TimeInterval? {
        self == .off ? nil : TimeInterval(rawValue * 60)
    }

    /// Localization key shown in the sleep timer menu.
    public var labelKey: String {
        switch self {
        case .off: return "Off"
        case .fifteen: return "15 min"
        case .thirty: return "30 min"
        case .sixty: return "60 min"
        }
    }
}

// MARK: - Up-Next channel navigation [DI-76]

extension VideoPlayerService {
    /// The list the HUD's previous/next buttons walk: the first candidate list that contains
    /// the current channel (e.g. playlist channels, then imported local videos). Empty when the
    /// channel belongs to none of them (live mirror, one-off server item), which hides the buttons.
    nonisolated public static func navigationQueue(for current: ChannelModel?,
                                                   candidates: [[ChannelModel]]) -> [ChannelModel] {
        guard let current else { return [] }
        return candidates.first { list in list.contains { matches($0, current) } } ?? []
    }

    /// The channel `offset` steps from `current`, wrapping at both ends. When `current` is not in
    /// the list, going forward starts at the first channel and going back at the last.
    nonisolated public static func adjacentChannel(from current: ChannelModel?,
                                                   in channels: [ChannelModel],
                                                   offset: Int) -> ChannelModel? {
        guard !channels.isEmpty, offset != 0 else { return nil }
        guard let current, let index = channels.firstIndex(where: { matches($0, current) }) else {
            return offset > 0 ? channels.first : channels.last
        }
        let count = channels.count
        let target = ((index + offset) % count + count) % count
        return target == index ? nil : channels[target]
    }

    nonisolated static func matches(_ lhs: ChannelModel, _ rhs: ChannelModel) -> Bool {
        lhs.id == rhs.id || lhs.streamURL == rhs.streamURL
    }

    /// Loads the next channel in `channels`. Returns the channel it switched to, if any.
    @discardableResult
    public func playNext(in channels: [ChannelModel]) -> ChannelModel? {
        step(in: channels, offset: 1)
    }

    /// Loads the previous channel in `channels`. Returns the channel it switched to, if any.
    @discardableResult
    public func playPrevious(in channels: [ChannelModel]) -> ChannelModel? {
        step(in: channels, offset: -1)
    }

    private func step(in channels: [ChannelModel], offset: Int) -> ChannelModel? {
        guard let target = Self.adjacentChannel(from: currentChannel, in: channels, offset: offset) else {
            return nil
        }
        load(channel: target)
        return target
    }
}

// MARK: - Sleep / parked-session timer [DI-76]

extension VideoPlayerService {
    /// Seconds left until `deadline`, never negative.
    nonisolated public static func sleepTimerRemaining(deadline: Date, now: Date) -> TimeInterval {
        max(0, deadline.timeIntervalSince(now))
    }

    /// Starts (or with `.off` cancels) the sleep timer. Selecting a preset again restarts it.
    public func setSleepTimer(_ preset: SleepTimerPreset, now: Date = Date()) {
        guard let duration = preset.duration else {
            cancelSleepTimer()
            return
        }
        sleepTimerTicker?.invalidate()
        sleepTimerPreset = preset
        sleepTimerDeadline = now.addingTimeInterval(duration)
        sleepTimerRemaining = duration
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickSleepTimer() }
        }
        ticker.tolerance = 0.2
        RunLoop.main.add(ticker, forMode: .common)
        sleepTimerTicker = ticker
    }

    public func cancelSleepTimer() {
        sleepTimerTicker?.invalidate()
        sleepTimerTicker = nil
        sleepTimerDeadline = nil
        sleepTimerRemaining = nil
        sleepTimerPreset = .off
    }

    /// Updates the countdown and, once the deadline passes, pauses playback and clears the timer.
    /// Called every second by the ticker and on returning to the foreground.
    func tickSleepTimer(now: Date = Date()) {
        guard let deadline = sleepTimerDeadline else { return }
        let remaining = Self.sleepTimerRemaining(deadline: deadline, now: now)
        guard remaining > 0 else {
            expireSleepTimer()
            return
        }
        sleepTimerRemaining = remaining
    }

    private func expireSleepTimer() {
        cancelSleepTimer()
        pause()
    }
}
