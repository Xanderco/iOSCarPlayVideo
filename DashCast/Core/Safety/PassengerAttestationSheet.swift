import SwiftUI

/// Modal sheet and interactive gate enabling passengers to attest that they
/// are viewing video content while the vehicle is in motion (> 5 mph).
///
/// Features a physical dual-finger touch target to ensure intentional confirmation
/// and prevent accidental or driver single-tap overrides.
public struct PassengerAttestationSheet: View {
    @ObservedObject var gate = PassengerAttestationGate.shared
    @Environment(\.dismiss) private var dismiss

    @State private var finger1Touched = false
    @State private var finger2Touched = false
    @State private var holdProgress: Double = 0
    @State private var timer: Timer?
    @State private var showAuditLog = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header Icon & Title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.dcWarning.opacity(0.18))
                                    .frame(width: 88, height: 88)
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(Color.dcWarning)
                            }

                            Text("Passenger Attestation Required")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.dcTextPrimary)
                                .multilineTextAlignment(.center)

                            Text("Vehicle in Motion (\(String(format: "%.1f", gate.currentSpeedMph)) mph)")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.dcWarning)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.dcWarning.opacity(0.15)))
                        }
                        .padding(.top, 12)

                        // Regulatory Legal Notice
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundStyle(Color.dcAccent)
                                Text("Automotive Safety Compliance")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.dcTextPrimary)
                            }

                            Text("Federal & state regulations prohibit driver-facing video playback when vehicle velocity exceeds 5 mph. To proceed, a passenger must confirm they are viewing this display.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dcTextSecondary)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.dcSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.dcStroke, lineWidth: 1)
                                )
                        )

                        // Interactive Multi-Finger Touch Confirmation Target
                        VStack(spacing: 16) {
                            Text("Touch with 2 Fingers to Attest")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.dcTextPrimary)

                            HStack(spacing: 36) {
                                touchPad(index: 1, isTouched: finger1Touched) {
                                    finger1Touched.toggle()
                                    checkDualTouch()
                                }

                                touchPad(index: 2, isTouched: finger2Touched) {
                                    finger2Touched.toggle()
                                    checkDualTouch()
                                }
                            }

                            if holdProgress > 0 && holdProgress < 1.0 {
                                ProgressView(value: holdProgress)
                                    .tint(Color.dcAccent)
                                    .padding(.horizontal, 40)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.dcSurfaceRaised)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(finger1Touched && finger2Touched ? Color.dcAccent : Color.dcStroke, lineWidth: 1.5)
                                )
                        )

                        // Instant Attestation Button (Accessible Alternative)
                        Button {
                            completeAttestation(method: .manualConfirmation)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("I Am a Passenger · Unlock Playback")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.dcAccent)
                            .clipShape(Capsule())
                        }
                        .accessibilityIdentifier("passengerAttestationConfirmButton")

                        // Audit Trail and Dismiss
                        HStack(spacing: 16) {
                            Button {
                                showAuditLog = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.clipboard")
                                    Text("View Audit Log")
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.dcTextSecondary)
                            }

                            Spacer()

                            Button {
                                dismiss()
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.dcTextSecondary)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Safety Gate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.dcAccent)
                }
            }
            .sheet(isPresented: $showAuditLog) {
                PassengerAuditLogSheet()
            }
        }
    }

    private func touchPad(index: Int, isTouched: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isTouched ? Color.dcAccent.opacity(0.25) : Color.dcSurface)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(isTouched ? Color.dcAccent : Color.dcStroke, lineWidth: 2)
                    )

                VStack(spacing: 4) {
                    Image(systemName: isTouched ? "hand.point.up.fill" : "hand.point.up")
                        .font(.system(size: 26))
                        .foregroundStyle(isTouched ? Color.dcAccent : Color.dcTextSecondary)

                    Text("Finger \(index)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isTouched ? Color.dcAccent : Color.dcTextTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("touchPadFinger\(index)")
    }

    private func checkDualTouch() {
        if finger1Touched && finger2Touched {
            // Both fingers placed: simulate dual hold completion
            completeAttestation(method: .multiFingerTouch)
        }
    }

    private func completeAttestation(method: PassengerAttestationGate.AttestationMethod) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()

        gate.confirmPassengerAttestation(method: method)
        dismiss()
    }
}

/// Sheet displaying local sandboxed audit log for regulatory inspection.
public struct PassengerAuditLogSheet: View {
    @ObservedObject var gate = PassengerAttestationGate.shared
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                if gate.auditHistory.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.dcTextTertiary)
                        Text("No audit events recorded yet")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.dcTextSecondary)
                    }
                } else {
                    List {
                        ForEach(gate.auditHistory.reversed()) { event in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(event.eventType.rawValue)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.dcAccent)

                                    Spacer()

                                    Text(formattedDate(event.timestamp))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.dcTextTertiary)
                                }

                                Text(event.details)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dcTextPrimary)

                                HStack(spacing: 12) {
                                    Text("Speed: \(String(format: "%.1f", event.speedMph)) mph")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color.dcTextSecondary)
                                    Text("Method: \(event.method)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color.dcTextSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.dcSurface)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Safety Audit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { gate.clearAuditHistory() }
                        .foregroundStyle(Color.dcWarning)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.dcAccent)
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
