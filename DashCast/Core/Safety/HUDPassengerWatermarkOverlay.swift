import SwiftUI

/// Unobtrusive HUD passenger watermark overlay displayed during in-motion video playback.
///
/// Complies with automotive safety standards by clearly communicating to observers
/// and vehicle occupants that video playback is operating under active passenger attestation.
public struct HUDPassengerWatermarkOverlay: View {
    @ObservedObject var gate = PassengerAttestationGate.shared
    public var isCompact: Bool

    public init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }

    public var body: some View {
        if gate.isPassengerModeActive && gate.isVehicleMovingAboveThreshold {
            HStack(spacing: 6) {
                Image(systemName: "person.2.badge.shield.checkmark.fill")
                    .font(.system(size: isCompact ? 11 : 13, weight: .semibold))
                    .foregroundStyle(Color.dcAccent)

                Text(isCompact ? "Passenger Mode Active" : "Passenger Mode Active · Eyes on Road")
                    .font(.system(size: isCompact ? 11 : 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)

                if !isCompact && gate.sessionTimeRemaining > 0 {
                    Text(formattedTimeRemaining)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .padding(.horizontal, isCompact ? 10 : 14)
            .padding(.vertical, isCompact ? 5 : 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.72))
                    .overlay(
                        Capsule()
                            .stroke(Color.dcAccent.opacity(0.6), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 2)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.easeInOut(duration: 0.25), value: gate.isPassengerModeActive)
            .accessibilityIdentifier("hudPassengerWatermarkBadge")
        }
    }

    private var formattedTimeRemaining: String {
        let mins = Int(gate.sessionTimeRemaining) / 60
        let secs = Int(gate.sessionTimeRemaining) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
