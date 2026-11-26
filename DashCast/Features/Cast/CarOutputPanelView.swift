import SwiftUI

/// Testable localization & status formatting helpers for `CarOutputPanelView`.
enum CarOutputPanelStatusFormatter {
    static let allLocalizationKeys: [String] = [
        "Video on the car display is for passengers and parked use only. DashCast pauses video and stops mirroring automatically when the vehicle starts moving.",
        "Parked · car video available",
        "Vehicle moving · video paused",
        "Checking vehicle motion…",
        "Video resumes only while the car stays parked.",
        "Pull over and park to continue watching on the car display.",
        "Allow Location and Motion access so DashCast can tell when you're parked.",
        "AirPlay to car display",
        "LIVE",
        "On iOS 26 and later, cars that support AirPlay video show up in the AirPlay menu while parked. AirPlay TVs, receivers and AirPlay-capable adapters work the same way.",
        "AirPlay displays found nearby",
        "No AirPlay display found yet",
        "Playing on %@",
        "Playing on AirPlay display",
        "AirPlay display",
        "CarPlay audio connected",
        "Tap to choose a display",
        "Mirror to car browser",
        "For cars and adapters with a web browser: connect the car to your iPhone's Personal Hotspot (or the same Wi-Fi), start mirroring, then open the address below in the car's browser.",
        "Mirror to CarPlay screen (beta)",
        "Shows the broadcast on the CarPlay display while parked, where supported.",
        "Mirroring is live",
        "Tap to start mirroring",
        "%lld car display(s) watching",
        "Turn on Personal Hotspot or join Wi-Fi to get a viewer address."
    ]

    static func parkedIcon(for state: VehicleMotionState) -> String {
        switch state {
        case .parked: return "parkingsign.circle.fill"
        case .moving: return "car.side.fill"
        case .unknown: return "location.circle"
        }
    }

    static func parkedTitleKeyName(for state: VehicleMotionState) -> String {
        switch state {
        case .parked: return "Parked · car video available"
        case .moving: return "Vehicle moving · video paused"
        case .unknown: return "Checking vehicle motion…"
        }
    }

    static func parkedSubtitleKeyName(for state: VehicleMotionState) -> String {
        switch state {
        case .parked: return "Video resumes only while the car stays parked."
        case .moving: return "Pull over and park to continue watching on the car display."
        case .unknown: return "Allow Location and Motion access so DashCast can tell when you're parked."
        }
    }

    static func airPlayStatusKeyName(
        isExternalPlaybackActive: Bool,
        airPlayRouteName: String?,
        isCarAudioRoute: Bool
    ) -> String {
        if isExternalPlaybackActive {
            let trimmed = airPlayRouteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "Playing on AirPlay display" : "Playing on %@"
        }
        if isCarAudioRoute {
            return "CarPlay audio connected"
        }
        return "Tap to choose a display"
    }

    static func airPlayDiscoveryKeyName(multipleRoutesDetected: Bool) -> String {
        multipleRoutesDetected ? "AirPlay displays found nearby" : "No AirPlay display found yet"
    }

    static func mirroringStatusKeyName(isBroadcasting: Bool) -> String {
        isBroadcasting ? "Mirroring is live" : "Tap to start mirroring"
    }

    static func cardBadgeKeyName(isActive: Bool) -> String? {
        isActive ? "LIVE" : nil
    }

    @MainActor
    static func parkedTitle(for state: VehicleMotionState) -> LocalizedStringKey {
        LocalizedStringKey(parkedTitleKeyName(for: state))
    }

    @MainActor
    static func parkedSubtitle(for state: VehicleMotionState) -> LocalizedStringKey {
        LocalizedStringKey(parkedSubtitleKeyName(for: state))
    }

    @MainActor
    static func airPlayStatusTitle(
        isExternalPlaybackActive: Bool,
        airPlayRouteName: String?,
        isCarAudioRoute: Bool
    ) -> LocalizedStringKey {
        if isExternalPlaybackActive {
            let trimmed = airPlayRouteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return LocalizedStringKey("Playing on \(trimmed)")
            }
            return LocalizedStringKey("Playing on AirPlay display")
        }
        if isCarAudioRoute {
            return LocalizedStringKey("CarPlay audio connected")
        }
        return LocalizedStringKey("Tap to choose a display")
    }

    @MainActor
    static func airPlayDiscoverySubtitle(multipleRoutesDetected: Bool) -> LocalizedStringKey {
        LocalizedStringKey(airPlayDiscoveryKeyName(multipleRoutesDetected: multipleRoutesDetected))
    }

    @MainActor
    static func mirroringStatusTitle(isBroadcasting: Bool) -> LocalizedStringKey {
        LocalizedStringKey(mirroringStatusKeyName(isBroadcasting: isBroadcasting))
    }

    @MainActor
    static func cardBadge(isActive: Bool) -> LocalizedStringKey? {
        cardBadgeKeyName(isActive: isActive).map { LocalizedStringKey($0) }
    }

    @MainActor
    static func viewerCountTitle(viewerCount: Int) -> LocalizedStringKey {
        LocalizedStringKey("\(viewerCount) car display(s) watching")
    }
}

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
        CarOutputPanelStatusFormatter.parkedIcon(for: parkedGuard.state)
    }

    private var parkedColor: Color {
        switch parkedGuard.state {
        case .parked: return .dashGreen
        case .moving: return .dashOrange
        case .unknown: return .dashTextSecondary
        }
    }

    private var parkedTitle: LocalizedStringKey {
        CarOutputPanelStatusFormatter.parkedTitle(for: parkedGuard.state)
    }

    private var parkedSubtitle: LocalizedStringKey {
        CarOutputPanelStatusFormatter.parkedSubtitle(for: parkedGuard.state)
    }

    // MARK: AirPlay

    private var airPlayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(
                icon: "airplayvideo",
                title: "AirPlay to car display",
                badge: CarOutputPanelStatusFormatter.cardBadge(isActive: output.isExternalPlaybackActive)
            )

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
                    Text(CarOutputPanelStatusFormatter.airPlayDiscoverySubtitle(multipleRoutesDetected: output.multipleRoutesDetected))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                }
                Spacer()
            }
        }
        .modifier(CardStyle())
    }

    private var airPlayStatusTitle: LocalizedStringKey {
        CarOutputPanelStatusFormatter.airPlayStatusTitle(
            isExternalPlaybackActive: output.isExternalPlaybackActive,
            airPlayRouteName: output.airPlayRouteName,
            isCarAudioRoute: output.isCarAudioRoute
        )
    }

    // MARK: Mirroring

    private var mirroringCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(
                icon: "rectangle.on.rectangle",
                title: "Mirror to car browser",
                badge: CarOutputPanelStatusFormatter.cardBadge(isActive: output.isBroadcasting)
            )

            Text("For cars and adapters with a web browser: connect the car to your iPhone's Personal Hotspot (or the same Wi-Fi), start mirroring, then open the address below in the car's browser.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dashTextSecondary)

            Toggle(isOn: $mirrorToCarPlay) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mirror to CarPlay screen (beta)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dashTextPrimary)
                    Text("Shows the broadcast on the CarPlay display while parked, where supported.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                }
            }
            .tint(Color.dashYellow)
            .onChange(of: mirrorToCarPlay) { enabled in
                CarMirrorFeature.setEnabled(enabled)
            }

            HStack(spacing: 12) {
                ScreenBroadcastPickerView()
                    .frame(width: 44, height: 44)
                    .background(Color.dashSurfaceHighlight)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(CarOutputPanelStatusFormatter.mirroringStatusTitle(isBroadcasting: output.isBroadcasting))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dashTextPrimary)
                    if output.isBroadcasting {
                        Text(CarOutputPanelStatusFormatter.viewerCountTitle(viewerCount: output.broadcastStatus.viewerCount))
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
                Label {
                    Text(verbatim: message)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.dashOrange)
            }
        }
        .modifier(CardStyle())
    }

    private func cardHeader(icon: String, title: LocalizedStringKey, badge: LocalizedStringKey?) -> some View {
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
