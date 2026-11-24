import SwiftUI
import AVKit

/// Native `AVRoutePickerView` configured for audio output selection (Bluetooth headphones,
/// AirPods, speaker, CarPlay) rather than video mirroring targets.
public struct AudioOutputRoutePickerRepresentable: UIViewRepresentable {
    public var tintColor: Color

    public init(tintColor: Color = .dcAccent) {
        self.tintColor = tintColor
    }

    public func makeUIView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        routePicker.tintColor = UIColor(tintColor)
        routePicker.activeTintColor = UIColor(Color.dcSuccess)
        routePicker.prioritizesVideoDevices = false
        routePicker.backgroundColor = .clear
        return routePicker
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = UIColor(tintColor)
    }
}

/// Compact pill badge displaying the current dual-zone audio routing state.
public struct DualZoneAudioBadgeView: View {
    @ObservedObject var router = DualZoneAudioRouter.shared

    public init() {}

    private var badgeTint: Color {
        switch router.activeZone {
        case .passengerHeadphones: return .dcSuccess
        case .cabinCoexistence: return .dcInfo
        case .cabinExclusive: return .dcAccent
        case .mutedSafetyGuard: return .dcWarning
        }
    }

    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: router.activeZone.iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(badgeTint)
            Text(router.activeZone.localizedBadgeTitle)
                .font(DSTypography.badge)
                .foregroundStyle(Color.dcTextPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(badgeTint.opacity(0.16))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(badgeTint.opacity(0.45), lineWidth: 1))
        .accessibilityIdentifier("DualZoneAudio_Badge")
    }
}

/// Sheet for configuring independent passenger Bluetooth headphone routing while preserving
/// CarPlay cabin navigation prompts and radio playback.
public struct DualZoneAudioSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var router = DualZoneAudioRouter.shared
    @ObservedObject private var playerService = VideoPlayerService.shared

    public init() {}

    private var zoneAccentColor: Color {
        switch router.activeZone {
        case .passengerHeadphones: return .dcSuccess
        case .cabinCoexistence: return .dcInfo
        case .cabinExclusive: return .dcAccent
        case .mutedSafetyGuard: return .dcWarning
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusHeroCard

                    if let banner = router.safetyMuteBannerMessage {
                        safetyAlertBanner(banner)
                    }

                    headphonePickerCard

                    routingModeCard

                    cabinProtectionCard

                    passengerVolumeCard

                    disconnectFallbackCard
                }
                .padding(16)
            }
            .background(Color.dcBackground.ignoresSafeArea())
            .navigationTitle("Dual-Zone Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcAccent)
                }
            }
            .onAppear {
                router.applyCurrentSessionPolicy(activate: false)
            }
        }
    }

    // MARK: - Cards

    private var statusHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(zoneAccentColor.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: router.activeZone.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(zoneAccentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(router.activeZone.localizedHeadline)
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)
                    Text(activeRouteSummary)
                        .font(DSTypography.footnote)
                        .foregroundStyle(Color.dcTextSecondary)
                }

                Spacer()
            }

            if !router.routeSnapshot.outputs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACTIVE OUTPUTS")
                        .font(DSTypography.badge)
                        .foregroundStyle(Color.dcTextTertiary)
                        .tracking(1.1)

                    ForEach(router.routeSnapshot.outputs) { endpoint in
                        HStack(spacing: 8) {
                            Image(systemName: endpoint.isPassengerHeadphone ? "headphones" : (endpoint.isCabinCarAudio ? "car.fill" : "speaker.wave.2"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(endpoint.isPassengerHeadphone ? Color.dcSuccess : Color.dcAccent)
                            Text(endpoint.name)
                                .font(DSTypography.subheadline)
                                .foregroundStyle(Color.dcTextPrimary)
                            Spacer()
                            Text(endpoint.kind.rawValue.uppercased())
                                .font(DSTypography.badge)
                                .foregroundStyle(Color.dcTextSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.dcSurfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(zoneAccentColor.opacity(0.45), lineWidth: 1)
        )
    }

    private func safetyAlertBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.dcWarning)
                Text(message)
                    .font(DSTypography.footnote)
                    .foregroundStyle(Color.dcTextPrimary)
            }

            HStack(spacing: 10) {
                Button {
                    router.overrideSafetyMuteToCabin()
                } label: {
                    Text("Unmute to Cabin")
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dcOnAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.dcAccent)
                        .clipShape(Capsule())
                }

                Button {
                    router.dismissSafetyBanner()
                } label: {
                    Text("Dismiss")
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dcTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.dcSurfaceRaised)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dcWarning.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dcWarning.opacity(0.45), lineWidth: 1)
        )
    }

    private var headphonePickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Passenger Bluetooth Output")
                .font(DSTypography.headline)
                .foregroundStyle(Color.dcTextPrimary)

            Text("Tap the audio picker to pair passenger AirPods or Bluetooth headphones for video sound while CarPlay keeps cabin audio separate.")
                .font(DSTypography.footnote)
                .foregroundStyle(Color.dcTextSecondary)

            HStack(spacing: 12) {
                AudioOutputRoutePickerRepresentable(tintColor: .dcAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.dcSurfaceRaised)
                    .clipShape(Circle())
                    .accessibilityIdentifier("DualZoneAudio_RoutePicker")

                VStack(alignment: .leading, spacing: 2) {
                    Text(router.routeSnapshot.hasHeadphonesConnected
                         ? (router.routeSnapshot.headphoneOutputs.first?.name ?? "Headphones Connected")
                         : "Select Passenger Headphones")
                        .font(DSTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.dcTextPrimary)

                    Text(router.routeSnapshot.hasHeadphonesConnected
                         ? "Independent passenger audio active"
                         : "AirPods, Beats, or wired headset")
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dcTextSecondary)
                }

                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dcStroke, lineWidth: 1)
        )
    }

    private var routingModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $router.isDualZoneEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dual-Zone Audio Splitter")
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("Isolate passenger video audio without muting cabin systems")
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            .tint(Color.dcAccent)
            .accessibilityIdentifier("DualZoneAudio_MasterToggle")

            if router.isDualZoneEnabled {
                Divider().background(Color.dcSeparator)

                ForEach(DualZoneRoutingMode.allCases) { mode in
                    Button {
                        router.routingMode = mode
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 18))
                                .foregroundStyle(router.routingMode == mode ? Color.dcAccent : Color.dcTextSecondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.localizedTitle)
                                    .font(DSTypography.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.dcTextPrimary)
                                Text(mode.localizedSubtitle)
                                    .font(DSTypography.caption)
                                    .foregroundStyle(Color.dcTextSecondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Image(systemName: router.routingMode == mode ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(router.routingMode == mode ? Color.dcAccent : Color.dcTextTertiary)
                        }
                        .padding(10)
                        .background(router.routingMode == mode ? Color.dcAccentSoft.opacity(0.45) : Color.dcSurfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dcStroke, lineWidth: 1)
        )
    }

    private var cabinProtectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $router.preserveCabinNavigation) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep CarPlay Navigation & Radio Active")
                        .font(DSTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("Mixes non-exclusively so turn-by-turn prompts and cabin radio keep playing.")
                        .font(DSTypography.caption)
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            .tint(Color.dcAccent)
        }
        .padding(14)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dcStroke, lineWidth: 1)
        )
    }

    private var passengerVolumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Passenger Stream Volume")
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dcTextPrimary)
                Spacer()
                Text("\(Int((router.effectivePlayerVolume * 100).rounded()))%")
                    .font(DSTypography.numeric)
                    .foregroundStyle(Color.dcAccent)
            }

            HStack(spacing: 12) {
                Button {
                    playerService.isMuted.toggle()
                } label: {
                    Image(systemName: (playerService.isMuted || router.isSafetyMuted) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle((playerService.isMuted || router.isSafetyMuted) ? Color.dcWarning : Color.dcAccent)
                        .frame(width: 34, height: 34)
                        .background(Color.dcSurfaceRaised)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Mute passenger audio")

                Slider(
                    value: Binding(
                        get: { Double(router.passengerVolumeTrim) },
                        set: { router.passengerVolumeTrim = Float($0) }
                    ),
                    in: 0.0...1.0,
                    step: 0.05
                )
                .tint(Color.dcAccent)
            }

            Text("Adjusts passenger video volume independently without changing your vehicle's head-unit volume.")
                .font(DSTypography.caption)
                .foregroundStyle(Color.dcTextSecondary)
        }
        .padding(14)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dcStroke, lineWidth: 1)
        )
    }

    private var disconnectFallbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("When Headphones Disconnect")
                .font(DSTypography.headline)
                .foregroundStyle(Color.dcTextPrimary)

            ForEach(HeadphoneDisconnectFallback.allCases) { policy in
                Button {
                    router.disconnectFallback = policy
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(policy.localizedTitle)
                                .font(DSTypography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.dcTextPrimary)
                            Text(policy.localizedSubtitle)
                                .font(DSTypography.caption)
                                .foregroundStyle(Color.dcTextSecondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        Image(systemName: router.disconnectFallback == policy ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(router.disconnectFallback == policy ? Color.dcAccent : Color.dcTextTertiary)
                    }
                    .padding(10)
                    .background(router.disconnectFallback == policy ? Color.dcAccentSoft.opacity(0.45) : Color.dcSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dcStroke, lineWidth: 1)
        )
    }

    private var activeRouteSummary: String {
        if let primary = router.routeSnapshot.activePrimaryEndpoint {
            return "\(primary.name) · \(router.preserveCabinNavigation ? "CarPlay Coexist" : "Exclusive")"
        }
        return "Default iOS audio route"
    }
}
