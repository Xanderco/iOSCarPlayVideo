import SwiftUI

/// Compact and expanded status badge for passenger distraction attestation and speed geofence.
public struct PassengerAttestationBadgeView: View {
    @ObservedObject var gate = PassengerAttestationGate.shared
    public var isCompact: Bool

    public init(isCompact: Bool = true) {
        self.isCompact = isCompact
    }

    public var body: some View {
        Button {
            gate.showAttestationSheet = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: badgeIcon)
                    .font(.system(size: isCompact ? 11 : 13, weight: .bold))
                    .foregroundStyle(badgeColor)

                if !isCompact {
                    Text(badgeTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.dcTextPrimary)
                }
            }
            .padding(.horizontal, isCompact ? 8 : 12)
            .padding(.vertical, isCompact ? 5 : 7)
            .background(
                Capsule()
                    .fill(Color.dcSurface)
                    .overlay(
                        Capsule()
                            .stroke(badgeColor.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .accessibilityLabel("Passenger Safety Attestation")
        .sheet(isPresented: $gate.showAttestationSheet) {
            PassengerAttestationSheet()
        }
    }

    private var badgeColor: Color {
        if gate.isVehicleMovingAboveThreshold {
            return gate.isPassengerModeActive ? Color.dcAccent : Color.dcWarning
        }
        return Color.dcTextSecondary
    }

    private var badgeIcon: String {
        if gate.isVehicleMovingAboveThreshold {
            return gate.isPassengerModeActive ? "person.2.badge.shield.checkmark.fill" : "hand.raised.fill"
        }
        return "shield.checkered"
    }

    private var badgeTitle: String {
        if gate.isVehicleMovingAboveThreshold {
            return gate.isPassengerModeActive ? "Passenger Active" : "Attestation Required"
        }
        return "Safety Gate"
    }
}
