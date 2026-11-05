import SwiftUI

/// "Car Display" panel: the two supported ways to get video onto the car's
/// screen, plus the parked-only status.
struct CarOutputPanelView: View {
    @ObservedObject private var output = CarVideoOutputController.shared
    @ObservedObject private var parkedGuard = CarVideoOutputController.shared.parkedGuard
    @State private var copiedURL = false
    @State private var mirrorToCarPlay = CarMirrorFeature.isEnabled()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                parkedStatusCard
                airPlayCard
                mirroringCard
                Text("Video on the car display is for passengers and parked use only. DashCast pauses video and stops mirroring automatically when the vehicle starts moving.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dcTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(16)
        }
        .background(Color.dcBackground.ignoresSafeArea())
        .onAppear { output.setPanelVisible(true) }
        .onDisappear { output.setPanelVisible(false) }
    }

    // MARK: Parked status

    private var parkedStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: parkedIcon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(parkedColor)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(parkedTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dcTextPrimary)
                Text(parkedSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dcTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(parkedColor.opacity(0.4), lineWidth: 1))
    }

    private var parkedIcon: String {
        switch parkedGuard.state {
        case .parked: return "parkingsign.circle.fill"
        case .moving: return "car.side.fill"
        case .unknown: return "location.circle"
        }
    }

    private var parkedColor: Color {
        switch parkedGuard.state {
        case .parked: return .dcSuccess
        case .moving: return .dcWarning
        case .unknown: return .dcTextSecondary
        }
    }

    private var parkedTitle: String {
        switch parkedGuard.state {
        case .parked: return "Parked · car video available"
        case .moving: return "Vehicle moving · video paused"
        case .unknown: return "Checking vehicle motion…"
        }
    }

    private var parkedSubtitle: String {
        switch parkedGuard.state {
        case .parked: return "Video resumes only while the car stays parked."
        case .moving: return "Pull over and park to continue watching on the car display."
        case .unknown: return "Allow Location and Motion access so DashCast can tell when you're parked."
        }
    }

    // MARK: AirPlay

    private var airPlayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(icon: "airplayvideo", title: "AirPlay to car display", badge: output.isExternalPlaybackActive ? "LIVE" : nil)

            Text("On iOS 26 and later, cars that support AirPlay video show up in the AirPlay menu while parked. AirPlay TVs, receivers and AirPlay-capable adapters work the same way.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dcTextSecondary)

            HStack(spacing: 12) {
                AirPlayRoutePickerRepresentable(tintColor: .dcAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.dcSurfaceRaised)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(airPlayStatusTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dcTextPrimary)
                    Text(output.multipleRoutesDetected ? "AirPlay displays found nearby" : "No AirPlay display found yet")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextTertiary)
                }
                Spacer()
            }

            if !output.multipleRoutesDetected && !output.isExternalPlaybackActive {
                noAirPlayDisplays
            }
        }
        .modifier(CardStyle())
    }

    /// Without any receiver nearby the system AirPlay menu is empty, so the button seemed to do
    /// nothing. Say so plainly and tell the user what to do.
    private var noAirPlayDisplays: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(Color.dcWarning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("No AirPlay displays found")
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dcTextPrimary)
                Text("Connect your iPhone to your car's or Apple TV's Wi-Fi, then come back. Displays show up here automatically.")
                    .font(DSTypography.footnote)
                    .foregroundStyle(Color.dcTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dcWarning.opacity(0.10), in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("CarDisplay_NoAirPlay")
    }

    private var airPlayStatusTitle: String {
        if output.isExternalPlaybackActive {
            return "Playing on \(output.airPlayRouteName ?? "AirPlay display")"
        }
        if output.isCarAudioRoute {
            return "CarPlay audio connected"
        }
        return "Tap to choose a display"
    }

    // MARK: Mirroring

    private var mirroringCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(icon: "rectangle.on.rectangle", title: "Mirror to car browser", badge: output.isBroadcasting ? "LIVE" : nil)

            Text("For cars and adapters with a web browser: connect the car to your iPhone's Personal Hotspot (or the same Wi-Fi), start mirroring, then open the address below in the car's browser.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dcTextSecondary)

            Toggle(isOn: $mirrorToCarPlay) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mirror to CarPlay screen (beta)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("Shows the broadcast on the CarPlay display while parked, where supported.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextTertiary)
                }
            }
            .tint(Color.dcAccent)
            .onChange(of: mirrorToCarPlay) { enabled in
                CarMirrorFeature.setEnabled(enabled)
            }

            HStack(spacing: 12) {
                ScreenBroadcastPickerView()
                    .frame(width: 44, height: 44)
                    .background(Color.dcSurfaceRaised)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(output.isBroadcasting ? "Mirroring is live" : "Tap to start mirroring")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dcTextPrimary)
                    if output.isBroadcasting {
                        Text("\(output.broadcastStatus.viewerCount) car display(s) watching")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dcTextTertiary)
                    }
                }
                Spacer()
            }

            if let url = output.broadcastStatus.viewerURL ?? LocalNetworkAddress.viewerURL(address: LocalNetworkAddress.preferredIPv4()) {
                Button {
                    UIPasteboard.general.string = url
                    copiedURL = true
                } label: {
                    HStack {
                        Text(url)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.dcAccent)
                        Spacer()
                        Image(systemName: copiedURL ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(Color.dcAccent)
                    }
                    .padding(12)
                    .background(Color.dcAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Text("Turn on Personal Hotspot or join Wi-Fi to get a viewer address.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dcTextTertiary)
            }

            if output.broadcastStatus.state == .stoppedForMotion, let message = output.broadcastStatus.message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dcWarning)
            }
        }
        .modifier(CardStyle())
    }

    private func cardHeader(icon: String, title: String, badge: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.dcAccent)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.dcTextPrimary)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dcSuccess)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dcSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dcStroke, lineWidth: 1))
    }
}

/// The car-display panel wrapped for presentation as a sheet (Home, browser hand-off fallback).
struct CarDisplaySheet: View {
    @Environment(\.dismiss) private var dismiss

    init() {}

    var body: some View {
        NavigationStack {
            CarOutputPanelView()
                .navigationTitle("Car Display")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .tint(Color.dcAccent)
    }
}
