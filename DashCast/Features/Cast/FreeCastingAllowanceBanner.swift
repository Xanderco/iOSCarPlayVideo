import SwiftUI

/// Presentation state and clean mm:ss formatting for the free-tier daily casting allowance banner.
public struct CastingAllowanceStatus: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Full daily allowance remains untouched (e.g. 15:00 of 15:00).
        case full
        /// Active free-tier session with at least 5 minutes remaining.
        case normal
        /// Less than 5 minutes (> 0s and < 300s) remaining today.
        case low
        /// Daily free casting allowance exhausted (0:00 remaining).
        case exhausted
    }

    public static let lowThresholdSeconds: TimeInterval = 5 * 60

    public let remainingSeconds: TimeInterval
    public let totalSeconds: TimeInterval
    public let state: State
    public let progress: Double
    public let formattedRemaining: String
    public let remainingMinutes: Int

    public init(
        remainingSeconds: TimeInterval,
        totalSeconds: TimeInterval = EntitlementGate.FreeTierLimits.standard.dailyCastingSeconds
    ) {
        let safeRemaining = remainingSeconds.isNaN ? 0 : max(0, remainingSeconds)
        let safeTotal = totalSeconds.isFinite && totalSeconds > 0 ? totalSeconds : 0

        self.remainingSeconds = safeRemaining
        self.totalSeconds = safeTotal

        if !safeRemaining.isFinite {
            self.state = .full
            self.progress = 1
            self.formattedRemaining = "∞"
            self.remainingMinutes = .max
            return
        }

        self.progress = safeTotal > 0 ? min(1, max(0, safeRemaining / safeTotal)) : 0
        self.formattedRemaining = Self.formatDuration(safeRemaining)
        self.remainingMinutes = Int(ceil(safeRemaining / 60))

        if safeRemaining <= 0 {
            self.state = .exhausted
        } else if safeTotal > 0 && safeRemaining >= safeTotal {
            self.state = .full
        } else if safeRemaining < Self.lowThresholdSeconds {
            self.state = .low
        } else {
            self.state = .normal
        }
    }

    @MainActor
    public init(gate: EntitlementGate) {
        self.init(
            remainingSeconds: gate.remainingCastingSeconds,
            totalSeconds: gate.limits.dailyCastingSeconds
        )
    }

    /// Formats remaining seconds as `m:ss`, keeping positive sub-second remainders at `0:01`.
    public static func formatDuration(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN else { return "0:00" }
        let clamped = max(0, seconds)
        guard clamped.isFinite else { return "∞" }
        let wholeSeconds = clamped > 0 ? max(1, Int(floor(clamped))) : 0
        let minutes = wholeSeconds / 60
        let remainder = wholeSeconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    public var titleFormatKey: String {
        switch state {
        case .full: return "Free casting · %@ daily"
        case .normal: return "Free casting · %@ left"
        case .low: return "Low casting time · %@ left"
        case .exhausted: return "Daily free casting limit reached"
        }
    }

    public var subtitleFormatKey: String {
        switch state {
        case .full: return "Upgrade to Pro for unlimited car casting"
        case .normal: return "Resets at midnight · Tap for Pro"
        case .low: return "Less than 5 min left today · Tap for Pro"
        case .exhausted: return "Resets at midnight · Unlock unlimited Pro"
        }
    }

    public var badgeFormatKey: String {
        switch state {
        case .full, .normal, .low: return "PRO"
        case .exhausted: return "Unlock Pro"
        }
    }

    public var titleKey: LocalizedStringKey {
        switch state {
        case .full: return LocalizedStringKey("Free casting · \(formattedRemaining) daily")
        case .normal: return LocalizedStringKey("Free casting · \(formattedRemaining) left")
        case .low: return LocalizedStringKey("Low casting time · \(formattedRemaining) left")
        case .exhausted: return "Daily free casting limit reached"
        }
    }

    public var subtitleKey: LocalizedStringKey {
        switch state {
        case .full: return "Upgrade to Pro for unlimited car casting"
        case .normal: return "Resets at midnight · Tap for Pro"
        case .low: return "Less than 5 min left today · Tap for Pro"
        case .exhausted: return "Resets at midnight · Unlock unlimited Pro"
        }
    }

    public var badgeKey: LocalizedStringKey {
        switch state {
        case .full, .normal, .low: return "PRO"
        case .exhausted: return "Unlock Pro"
        }
    }
}

/// Compact badge/meter showing remaining daily free casting time and opening the paywall in 1 tap.
public struct FreeCastingAllowanceBanner: View {
    @ObservedObject private var gate: EntitlementGate
    @Environment(\.scenePhase) private var scenePhase

    private let accessibilityIdentifier: String
    private let onUpgrade: () -> Void

    public init(
        gate: EntitlementGate = .shared,
        accessibilityIdentifier: String = "Cast_FreeAllowanceBanner",
        onUpgrade: @escaping () -> Void
    ) {
        self.gate = gate
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onUpgrade = onUpgrade
    }

    private var status: CastingAllowanceStatus {
        let _ = gate.castingSecondsUsedToday
        return CastingAllowanceStatus(gate: gate)
    }

    private var accentColor: Color {
        switch status.state {
        case .full, .normal: return .dcAccent
        case .low: return .dcWarning
        case .exhausted: return .dcDanger
        }
    }

    private var borderColor: Color {
        switch status.state {
        case .full, .normal: return .dcStroke
        case .low: return .dcWarning.opacity(0.45)
        case .exhausted: return .dcDanger.opacity(0.55)
        }
    }

    private var iconName: String {
        switch status.state {
        case .full, .normal: return "timer"
        case .low: return "exclamationmark.triangle.fill"
        case .exhausted: return "lock.fill"
        }
    }

    public var body: some View {
        let current = status
        Button(action: onUpgrade) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accentColor)
                        .frame(width: 30, height: 30)
                        .background(accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.titleKey)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.dcTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(current.subtitleKey)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dcTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(current.badgeKey)
                            .font(.system(size: 11, weight: .heavy))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(LinearGradient.dcProGradient)
                    .clipShape(Capsule())
                }

                ProgressView(value: current.progress)
                    .progressViewStyle(.linear)
                    .tint(accentColor)
                    .scaleEffect(x: 1, y: 1.35, anchor: .center)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.dcSurface)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: DSStroke.regular)
            )
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(current.formattedRemaining)
        .accessibilityHint(Text("Opens DashCast Pro upgrade options"))
        .accessibilityIdentifier(accessibilityIdentifier)
        .onAppear {
            gate.refreshUsage()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                gate.refreshUsage()
            }
        }
    }
}
