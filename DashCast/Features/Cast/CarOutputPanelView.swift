import SwiftUI

/// "Car Display" panel: the two supported ways to get video onto the car's
/// screen, plus the parked-only status.
struct CarOutputPanelView: View {
    @ObservedObject private var output = CarVideoOutputController.shared
    @ObservedObject private var parkedGuard = CarVideoOutputController.shared.parkedGuard
    @State private var copiedURL = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                parkedStatusCard
                airPlayCard
                mirroringCard
                Text("Video on the car display is for passengers and parked use only. DashCast pauses video and stops mirroring automatically when the vehicle starts moving.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(16)
        }
        .background(Color.dashBackground.ignoresSafeArea())
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
                    .foregroundStyle(Color.dashTextPrimary)
                Text(parkedSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.dashSurface)
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
        case .parked: return .dashGreen
        case .moving: return .dashOrange
        case .unknown: return .dashTextSecondary
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
                .foregroundStyle(Color.dashTextSecondary)

            HStack(spacing: 12) {
                AirPlayRoutePickerRepresentable(tintColor: .dashYellow)
                    .frame(width: 44, height: 44)
                    .background(Color.dashSurfaceHighlight)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(airPlayStatusTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dashTextPrimary)
                    Text(output.multipleRoutesDetected ? "AirPlay displays found nearby" : "No AirPlay display found yet")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                }
                Spacer()
            }
        }
        .modifier(CardStyle())
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
                .foregroundStyle(Color.dashTextSecondary)

            HStack(spacing: 12) {
                ScreenBroadcastPickerView()
                    .frame(width: 44, height: 44)
                    .background(Color.dashSurfaceHighlight)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(output.isBroadcasting ? "Mirroring is live" : "Tap to start mirroring")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dashTextPrimary)
                    if output.isBroadcasting {
                        Text("\(output.broadcastStatus.viewerCount) car display(s) watching")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dashTextMuted)
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
                            .foregroundStyle(Color.dashYellow)
                        Spacer()
                        Image(systemName: copiedURL ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(Color.dashYellow)
                    }
                    .padding(12)
                    .background(Color.dashYellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Text("Turn on Personal Hotspot or join Wi-Fi to get a viewer address.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextMuted)
            }

            if output.broadcastStatus.state == .stoppedForMotion, let message = output.broadcastStatus.message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashOrange)
            }
        }
        .modifier(CardStyle())
    }

    private func cardHeader(icon: String, title: String, badge: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.dashYellow)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.dashTextPrimary)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dashGreen)
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
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dashBorder, lineWidth: 1))
    }
}
