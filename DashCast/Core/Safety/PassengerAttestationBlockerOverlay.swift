import SwiftUI

/// Obscuring overlay displayed over video playback when vehicle speed exceeds 5 mph
/// without active passenger attestation.
public struct PassengerAttestationBlockerOverlay: View {
    @ObservedObject var gate = PassengerAttestationGate.shared

    public init() {}

    public var body: some View {
        if gate.isAttestationRequired && gate.isVehicleMovingAboveThreshold {
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.88))
                    .background(.ultraThinMaterial)

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.dcOrange.opacity(0.2))
                            .frame(width: 72, height: 72)
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.dcOrange)
                    }

                    Text("Video Playback Paused")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text("Vehicle is moving at \(String(format: "%.1f", gate.currentSpeedMph)) mph. Confirm passenger viewing to unlock video.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button {
                        gate.showAttestationSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                            Text("I Am a Passenger · Attest")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.dcAccent)
                        .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("unlockPassengerPlaybackButton")
                }
                .padding(24)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: gate.isAttestationRequired)
            .sheet(isPresented: $gate.showAttestationSheet) {
                PassengerAttestationSheet()
            }
        }
    }
}
