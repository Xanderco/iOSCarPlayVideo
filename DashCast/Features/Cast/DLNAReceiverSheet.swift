import SwiftUI

/// Control panel for the local DLNA/UPnP MediaRenderer receiver.
/// Lets passengers discover DashCast on the car hotspot / Wi-Fi, customize the
/// display name, and manage the incoming cast queue.
public struct DLNAReceiverSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = DLNAReceiverService.shared
    @ObservedObject private var parkedGuard = CarVideoOutputController.shared.parkedGuard
    @State private var copiedEndpoint = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DSSpacing.lg) {
                        visibilityCard
                        displayIdentityCard
                        if service.blockedByMotion || parkedGuard.state == .moving {
                            motionNoticeCard
                        }
                        if let errorMessage = service.lastErrorMessage, !service.blockedByMotion {
                            errorBanner(errorMessage)
                        }
                        incomingQueueCard
                    }
                    .padding(DSSpacing.lg)
                    .padding(.bottom, DSSpacing.xl)
                }
            }
            .navigationTitle("DLNA Receiver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.dcAccent)
                }
            }
        }
    }

    // MARK: - Cards

    private var visibilityCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                        .fill(service.isEnabled ? Color.dcAccentSoft : Color.dcSurfaceRaised)
                        .frame(width: 46, height: 46)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(service.isEnabled ? Color.dcAccent : Color.dcTextSecondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Discoverable on Wi-Fi")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)
                    Text(statusSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextSecondary)
                }

                Spacer()

                Toggle("", isOn: $service.isEnabled)
                    .labelsHidden()
                    .tint(Color.dcAccent)
                    .accessibilityIdentifier("DLNA_VisibilityToggle")
            }

            if service.isEnabled {
                HStack(spacing: DSSpacing.sm) {
                    Circle()
                        .fill(service.isListening ? Color.dcSuccess : Color.dcWarning)
                        .frame(width: 8, height: 8)
                    Text(service.isListening ? "Ready for DLNA / UPnP apps" : "Starting local receiver…")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dcTextSecondary)
                    Spacer()
                    Text(transportBadgeText)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.dcOnAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.dcAccent)
                        .clipShape(Capsule())
                }
            }
        }
        .dsCard()
    }

    private var statusSubtitle: LocalizedStringKey {
        if service.isEnabled {
            return "Passengers on the same hotspot or Wi-Fi can cast directly to DashCast."
        }
        return "Turn on to accept media pushed from DLNA or UPnP apps."
    }

    private var transportBadgeText: LocalizedStringKey {
        switch service.currentTransportState {
        case .playing: return "PLAYING"
        case .paused: return "PAUSED"
        case .transitioning: return "LOADING"
        case .stopped: return "STANDBY"
        }
    }

    private var displayIdentityCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Car Display Name")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.dcTextPrimary)

            TextField("DashCast Car Display", text: $service.friendlyName)
                .padding(DSSpacing.md)
                .background(Color.dcSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                        .stroke(Color.dcStroke, lineWidth: DSStroke.regular)
                )
                .foregroundStyle(Color.dcTextPrimary)
                .accessibilityIdentifier("DLNA_FriendlyNameField")

            if let endpoint = service.serverURLString {
                Button {
                    UIPasteboard.general.string = endpoint
                    copiedEndpoint = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("UPnP Descriptor URL")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.dcTextSecondary)
                            Text(endpoint)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.dcAccent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Image(systemName: copiedEndpoint ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(Color.dcAccent)
                    }
                    .padding(DSSpacing.md)
                    .background(Color.dcAccentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .dsCard()
    }

    private var motionNoticeCard: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: "car.side.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.dcWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vehicle moving · DLNA paused")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.dcTextPrimary)
                Text("Incoming DLNA streams resume automatically when parked.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dcTextSecondary)
            }
            Spacer()
        }
        .padding(DSSpacing.lg)
        .background(Color.dcSurface, in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .strokeBorder(Color.dcWarning.opacity(0.45), lineWidth: DSStroke.regular)
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.dcWarning)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.dcTextPrimary)
            Spacer()
        }
        .padding(DSSpacing.md)
        .background(Color.dcSurface, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .strokeBorder(Color.dcWarning.opacity(0.4), lineWidth: DSStroke.regular)
        )
    }

    private var incomingQueueCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack {
                Text("Incoming Stream Queue")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.dcTextPrimary)
                Spacer()
                if !service.incomingQueue.isEmpty {
                    Button("Clear") {
                        service.clearQueue()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dcAccent)
                    .accessibilityIdentifier("DLNA_ClearQueueButton")
                }
            }

            if service.incomingQueue.isEmpty {
                VStack(spacing: DSSpacing.sm) {
                    Image(systemName: "tv.and.mediabox")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.dcTextTertiary)
                    Text("No Incoming Streams Yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("Open a DLNA-compatible player on another phone or laptop and select \"\(service.effectiveFriendlyName)\".")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dcTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.xl)
            } else {
                VStack(spacing: DSSpacing.sm) {
                    ForEach(service.incomingQueue) { item in
                        HStack(spacing: DSSpacing.md) {
                            Button {
                                service.playQueueItem(item)
                            } label: {
                                HStack(spacing: DSSpacing.md) {
                                    Image(systemName: service.activeItemID == item.id && service.currentTransportState == .playing ? "speaker.wave.2.fill" : "play.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.dcAccent)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.dcTextPrimary)
                                            .lineLimit(1)
                                        Text(item.streamURL.host ?? item.streamURL.absoluteString)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.dcTextSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                service.removeQueueItem(item)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dcTextTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(DSSpacing.md)
                        .background(Color.dcSurfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                    }
                }
            }
        }
        .dsCard()
    }
}
