import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Pure URL trimming and validation helpers for `CastHomeView`.
public enum CastHomeURLInputValidator {
    nonisolated public static func normalizedInput(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated public static func isValidStreamInput(_ raw: String) -> Bool {
        let normalized = normalizedInput(raw)
        guard !normalized.isEmpty,
              let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            return false
        }
        return true
    }

    nonisolated public static func isSingleHLSStreamURL(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "m3u8"
    }
}

/// Localized copy keys and formatting helpers for `CastHomeView`.
public enum CastHomeCopy {
    nonisolated public static let castTitleString = "Cast"
    nonisolated public static let proBadgeString = "PRO"
    nonisolated public static let carDisplayTitleString = "Car Display"
    nonisolated public static let closeString = "Close"
    nonisolated public static let couldntImportVideoString = "Couldn't import video"
    nonisolated public static let okString = "OK"
    nonisolated public static let mediaSourcesString = "Media Sources"
    nonisolated public static let mediaSourcesSubtitleString = "Playlists, Jellyfin, Emby & QR"
    nonisolated public static let localVideosString = "Local Videos"
    nonisolated public static let importingString = "Importing…"
    nonisolated public static let importFromPhotosString = "Import from Photos"
    nonisolated public static let mirrorIPhoneString = "Mirror iPhone"
    nonisolated public static let shareScreenLiveString = "Share your screen live"
    nonisolated public static let browserString = "Browser"
    nonisolated public static let exploreWebsitesString = "Explore websites"
    nonisolated public static let yourVideosString = "Your Videos"
    nonisolated public static let deleteVideoFormatString = "Delete %@"
    nonisolated public static let dashCastBrandString = "DashCast"
    nonisolated public static let displayConnectedString = "Display Connected"
    nonisolated public static let carPlayScreenString = "CarPlay Screen"
    nonisolated public static let externalDisplayConnectedString = "External display connected"
    nonisolated public static let noExternalDisplayString = "No external display (use AirPlay or a cable)"
    nonisolated public static let playingOnCarDisplayString = "Playing video & audio on car display while parked."
    nonisolated public static let connectToWatchInCarString = "Connect to watch in your car. You can still explore on iPhone."
    nonisolated public static let helpString = "Help"
    nonisolated public static let mediaServersSectionString = "Media Servers (Jellyfin & Emby)"
    nonisolated public static let addServerString = "Add Server"
    nonisolated public static let connectJellyfinEmbyString = "Connect Jellyfin / Emby"
    nonisolated public static let homeMediaServerSubtitleString = "Stream movies & shows from your home media server"
    nonisolated public static let manageAllServersString = "Manage All Servers"
    nonisolated public static let sampleStreamsString = "Sample Streams"
    nonisolated public static let yourChannelsString = "Your Channels"
    nonisolated public static let scanQRString = "Scan QR"
    nonisolated public static let scanQRCodeString = "Scan QR Code"
    nonisolated public static let fromURLString = "From URL"
    nonisolated public static let fromFilesString = "From Files"
    nonisolated public static let refreshAllString = "Refresh All"
    nonisolated public static let addSourceButtonString = "+ Add Source"
    nonisolated public static let scanPlaylistQRCodeString = "Scan Playlist QR Code"
    nonisolated public static let scanQRPromptSubtitleString = "Point camera at an M3U / M3U8 QR code"
    nonisolated public static let playlistChannelCountFormatString = "%@ · %lld channels"
    nonisolated public static let importedChannelsFormatString = "Imported %lld channels from %@"
    nonisolated public static let couldntImportPlaylistString = "Couldn't import playlist"
    nonisolated public static let doneString = "Done"
    nonisolated public static let noFavoritesYetString = "No Favorites Yet"
    nonisolated public static let favoritesEmptySubtitleString = "Save videos and web bookmarks to quickly access them in your car."
    nonisolated public static let favoritesTitleString = "Favorites"
    nonisolated public static let addCustomStreamTitleString = "Add Custom M3U / M3U8 Stream"
    nonisolated public static let playlistURLPlaceholderString = "https://example.com/playlist.m3u"
    nonisolated public static let importPlaylistString = "Import Playlist"
    nonisolated public static let pasteStreamURLHintString = "Paste an M3U / M3U8 playlist link or a single HLS stream URL."
    nonisolated public static let addStreamTitleString = "Add Stream"
    nonisolated public static let cancelString = "Cancel"
    nonisolated public static let addedStreamFormatString = "Added stream %@"

    nonisolated public static let allLocalizationKeys: [String] = [
        castTitleString,
        proBadgeString,
        carDisplayTitleString,
        closeString,
        couldntImportVideoString,
        okString,
        mediaSourcesString,
        mediaSourcesSubtitleString,
        localVideosString,
        importingString,
        importFromPhotosString,
        mirrorIPhoneString,
        shareScreenLiveString,
        browserString,
        exploreWebsitesString,
        yourVideosString,
        deleteVideoFormatString,
        dashCastBrandString,
        displayConnectedString,
        carPlayScreenString,
        externalDisplayConnectedString,
        noExternalDisplayString,
        playingOnCarDisplayString,
        connectToWatchInCarString,
        helpString,
        mediaServersSectionString,
        addServerString,
        connectJellyfinEmbyString,
        homeMediaServerSubtitleString,
        manageAllServersString,
        sampleStreamsString,
        yourChannelsString,
        scanQRString,
        scanQRCodeString,
        fromURLString,
        fromFilesString,
        refreshAllString,
        addSourceButtonString,
        scanPlaylistQRCodeString,
        scanQRPromptSubtitleString,
        playlistChannelCountFormatString,
        importedChannelsFormatString,
        couldntImportPlaylistString,
        doneString,
        noFavoritesYetString,
        favoritesEmptySubtitleString,
        favoritesTitleString,
        addCustomStreamTitleString,
        playlistURLPlaceholderString,
        importPlaylistString,
        pasteStreamURLHintString,
        addStreamTitleString,
        cancelString,
        addedStreamFormatString
    ]

    @MainActor public static var castTitleKey: LocalizedStringKey { LocalizedStringKey(castTitleString) }
    @MainActor public static var proBadgeKey: LocalizedStringKey { LocalizedStringKey(proBadgeString) }
    @MainActor public static var carDisplayTitleKey: LocalizedStringKey { LocalizedStringKey(carDisplayTitleString) }
    @MainActor public static var closeKey: LocalizedStringKey { LocalizedStringKey(closeString) }
    @MainActor public static var couldntImportVideoKey: LocalizedStringKey { LocalizedStringKey(couldntImportVideoString) }
    @MainActor public static var okKey: LocalizedStringKey { LocalizedStringKey(okString) }
    @MainActor public static var mediaSourcesKey: LocalizedStringKey { LocalizedStringKey(mediaSourcesString) }
    @MainActor public static var mediaSourcesSubtitleKey: LocalizedStringKey { LocalizedStringKey(mediaSourcesSubtitleString) }
    @MainActor public static var localVideosKey: LocalizedStringKey { LocalizedStringKey(localVideosString) }
    @MainActor public static var importingKey: LocalizedStringKey { LocalizedStringKey(importingString) }
    @MainActor public static var importFromPhotosKey: LocalizedStringKey { LocalizedStringKey(importFromPhotosString) }
    @MainActor public static var mirrorIPhoneKey: LocalizedStringKey { LocalizedStringKey(mirrorIPhoneString) }
    @MainActor public static var shareScreenLiveKey: LocalizedStringKey { LocalizedStringKey(shareScreenLiveString) }
    @MainActor public static var browserKey: LocalizedStringKey { LocalizedStringKey(browserString) }
    @MainActor public static var exploreWebsitesKey: LocalizedStringKey { LocalizedStringKey(exploreWebsitesString) }
    @MainActor public static var yourVideosKey: LocalizedStringKey { LocalizedStringKey(yourVideosString) }
    @MainActor public static var dashCastBrandKey: LocalizedStringKey { LocalizedStringKey(dashCastBrandString) }
    @MainActor public static var displayConnectedKey: LocalizedStringKey { LocalizedStringKey(displayConnectedString) }
    @MainActor public static var carPlayScreenKey: LocalizedStringKey { LocalizedStringKey(carPlayScreenString) }
    @MainActor public static var externalDisplayConnectedKey: LocalizedStringKey { LocalizedStringKey(externalDisplayConnectedString) }
    @MainActor public static var noExternalDisplayKey: LocalizedStringKey { LocalizedStringKey(noExternalDisplayString) }
    @MainActor public static var playingOnCarDisplayKey: LocalizedStringKey { LocalizedStringKey(playingOnCarDisplayString) }
    @MainActor public static var connectToWatchInCarKey: LocalizedStringKey { LocalizedStringKey(connectToWatchInCarString) }
    @MainActor public static var helpKey: LocalizedStringKey { LocalizedStringKey(helpString) }
    @MainActor public static var mediaServersSectionKey: LocalizedStringKey { LocalizedStringKey(mediaServersSectionString) }
    @MainActor public static var addServerKey: LocalizedStringKey { LocalizedStringKey(addServerString) }
    @MainActor public static var connectJellyfinEmbyKey: LocalizedStringKey { LocalizedStringKey(connectJellyfinEmbyString) }
    @MainActor public static var homeMediaServerSubtitleKey: LocalizedStringKey { LocalizedStringKey(homeMediaServerSubtitleString) }
    @MainActor public static var manageAllServersKey: LocalizedStringKey { LocalizedStringKey(manageAllServersString) }
    @MainActor public static var sampleStreamsKey: LocalizedStringKey { LocalizedStringKey(sampleStreamsString) }
    @MainActor public static var yourChannelsKey: LocalizedStringKey { LocalizedStringKey(yourChannelsString) }
    @MainActor public static var scanQRKey: LocalizedStringKey { LocalizedStringKey(scanQRString) }
    @MainActor public static var scanQRCodeKey: LocalizedStringKey { LocalizedStringKey(scanQRCodeString) }
    @MainActor public static var fromURLKey: LocalizedStringKey { LocalizedStringKey(fromURLString) }
    @MainActor public static var fromFilesKey: LocalizedStringKey { LocalizedStringKey(fromFilesString) }
    @MainActor public static var refreshAllKey: LocalizedStringKey { LocalizedStringKey(refreshAllString) }
    @MainActor public static var addSourceButtonKey: LocalizedStringKey { LocalizedStringKey(addSourceButtonString) }
    @MainActor public static var scanPlaylistQRCodeKey: LocalizedStringKey { LocalizedStringKey(scanPlaylistQRCodeString) }
    @MainActor public static var scanQRPromptSubtitleKey: LocalizedStringKey { LocalizedStringKey(scanQRPromptSubtitleString) }
    @MainActor public static var couldntImportPlaylistKey: LocalizedStringKey { LocalizedStringKey(couldntImportPlaylistString) }
    @MainActor public static var doneKey: LocalizedStringKey { LocalizedStringKey(doneString) }
    @MainActor public static var noFavoritesYetKey: LocalizedStringKey { LocalizedStringKey(noFavoritesYetString) }
    @MainActor public static var favoritesEmptySubtitleKey: LocalizedStringKey { LocalizedStringKey(favoritesEmptySubtitleString) }
    @MainActor public static var favoritesTitleKey: LocalizedStringKey { LocalizedStringKey(favoritesTitleString) }
    @MainActor public static var addCustomStreamTitleKey: LocalizedStringKey { LocalizedStringKey(addCustomStreamTitleString) }
    @MainActor public static var playlistURLPlaceholderKey: LocalizedStringKey { LocalizedStringKey(playlistURLPlaceholderString) }
    @MainActor public static var importPlaylistKey: LocalizedStringKey { LocalizedStringKey(importPlaylistString) }
    @MainActor public static var pasteStreamURLHintKey: LocalizedStringKey { LocalizedStringKey(pasteStreamURLHintString) }
    @MainActor public static var addStreamTitleKey: LocalizedStringKey { LocalizedStringKey(addStreamTitleString) }
    @MainActor public static var cancelKey: LocalizedStringKey { LocalizedStringKey(cancelString) }

    @MainActor
    public static func deleteVideoAccessibilityLabel(_ name: String) -> LocalizedStringKey {
        LocalizedStringKey("Delete \(name)")
    }

    @MainActor
    public static func playlistChannelCountKey(title: String, count: Int) -> LocalizedStringKey {
        LocalizedStringKey("\(title) · \(count) channels")
    }

    nonisolated public static func importedChannelsMessage(
        count: Int,
        title: String,
        bundle: Bundle = .main
    ) -> String {
        let format = String(localized: String.LocalizationValue(importedChannelsFormatString), bundle: bundle)
        return String(format: format, Int64(count), title)
    }

    nonisolated public static func addedStreamMessage(
        name: String,
        bundle: Bundle = .main
    ) -> String {
        let format = String(localized: String.LocalizationValue(addedStreamFormatString), bundle: bundle)
        return String(format: format, name)
    }
}

public struct CastHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var playerService = VideoPlayerService.shared
    @StateObject private var localVideoManager = LocalVideoManager.shared
    @StateObject private var externalDisplay = ExternalDisplayManager.shared

    @State private var showingAddM3UDialog: Bool = false
    @State private var showingPlaylistsSheet: Bool = false
    @State private var showingWebBrowser: Bool = false
    @State private var showingCastGuide: Bool = false
    @State private var showingFavorites: Bool = false
    @State private var showingBroadcastPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isFullscreenPlayer: Bool = false
    @State private var m3uURLInput: String = ""
    @StateObject private var playlistStore = PlaylistStore.shared
    @StateObject private var mediaServerStore = MediaServerStore.shared
    @State private var isImportingPlaylist: Bool = false
    @State private var showingPlaylistFileImporter: Bool = false
    @State private var showingQRScanner: Bool = false
    @State private var showingAddServer: Bool = false
    @State private var importErrorMessage: String?
    @State private var importSuccessMessage: String?
    @State private var localImportError: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // If video is currently playing, render the video player
                        if playerService.currentChannel != nil {
                            AutomotiveVideoPlayerView(isFullscreen: $isFullscreenPlayer)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .padding(.horizontal, 16)
                        }

                        // Main 4-Row Source Menu Card
                        mainSourceMenuCard

                        // Imported videos were previously saved but never listed anywhere,
                        // so the user had no way to play them.
                        if localVideoManager.isImporting || !localVideoManager.localVideos.isEmpty {
                            localVideosSection
                        }

                        // CarPlay Connection Illustration & Status Section
                        carPlayStatusSection
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 110) // clearance for LiquidCapsuleTabBar
                }
            }
            .navigationTitle(CastHomeCopy.castTitleKey)
            .task {
                // App Store screenshot launch arguments (no effect on normal launches).
                if ScreenshotLaunch.playDemoVideo, playerService.currentChannel == nil,
                   let demo = playlistStore.sampleChannels.first {
                    playerService.load(channel: demo)
                }
                if ScreenshotLaunch.showMediaSources { showingPlaylistsSheet = true }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        if !appState.isProLifetimeUnlocked {
                            Button {
                                appState.showPaywall = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11))
                                    Text(CastHomeCopy.proBadgeKey)
                                        .font(.system(size: 12, weight: .heavy))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(LinearGradient.dashProGoldGradient)
                                .foregroundStyle(Color.black)
                                .clipShape(Capsule())
                            }
                        }

                        Button {
                            showingCastGuide = true
                        } label: {
                            Image(systemName: "questionmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.dashTextPrimary)
                                .frame(width: 34, height: 34)
                                .background(Color.dashSurface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.dashBorder, lineWidth: 1))
                        }

                        Button {
                            showingFavorites = true
                        } label: {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dashTextPrimary)
                                .frame(width: 34, height: 34)
                                .background(Color.dashSurface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.dashBorder, lineWidth: 1))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCastGuide) {
                CarCastGuideModalView()
            }
            .sheet(isPresented: $showingWebBrowser) {
                WebVideoBrowserView()
                    // The tab-level paywall can't present over this sheet, so present it here too.
                    .sheet(isPresented: $appState.showPaywall) {
                        LifetimePaywallView().environmentObject(appState)
                    }
            }
            .sheet(isPresented: $showingPlaylistsSheet) {
                mediaSourcePlaylistsSheet
                    // The tab-level paywall can't present over this sheet, so present it here too.
                    .sheet(isPresented: $appState.showPaywall) {
                        LifetimePaywallView().environmentObject(appState)
                    }
            }
            .sheet(isPresented: $showingFavorites) {
                favoritesSheet
                    // The tab-level paywall can't present over this sheet, so present it here too.
                    .sheet(isPresented: $appState.showPaywall) {
                        LifetimePaywallView().environmentObject(appState)
                    }
            }
            .sheet(isPresented: $showingBroadcastPicker) {
                NavigationStack {
                    CarOutputPanelView()
                        .navigationTitle(CastHomeCopy.carDisplayTitleKey)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(CastHomeCopy.closeKey) { showingBroadcastPicker = false }
                                    .foregroundStyle(Color.dashYellow)
                            }
                        }
                }
                // The tab-level paywall can't present over this sheet, so present it here too.
                .sheet(isPresented: $appState.showPaywall) {
                    LifetimePaywallView().environmentObject(appState)
                }
            }
            .onChange(of: selectedPhotoItem) { (newItem: PhotosPickerItem?) in
                guard let newItem = newItem else { return }
                Task {
                    do {
                        let channel = try await localVideoManager.importVideo(from: newItem)
                        playerService.load(channel: channel)
                    } catch {
                        localImportError = error.localizedDescription
                    }
                    // Reset so picking the same video again still triggers onChange.
                    selectedPhotoItem = nil
                }
            }
            .alert(CastHomeCopy.couldntImportVideoKey, isPresented: Binding(
                get: { localImportError != nil },
                set: { if !$0 { localImportError = nil } }
            )) {
                Button(CastHomeCopy.okKey, role: .cancel) { localImportError = nil }
            } message: {
                Text(localImportError ?? "")
            }
        }
    }

    // MARK: - 4-Row Source Menu Card

    private var mainSourceMenuCard: some View {
        VStack(spacing: 1) {
            // Row 1: Media Sources
            Button {
                showingPlaylistsSheet = true
            } label: {
                menuRow(
                    icon: "play.tv.fill",
                    title: CastHomeCopy.mediaSourcesKey,
                    subtitle: CastHomeCopy.mediaSourcesSubtitleKey
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Cast_MediaSourceRow")

            Divider().background(Color.dashBorder.opacity(0.6))

            // Row 2: Local Videos
            PhotosPicker(selection: $selectedPhotoItem, matching: .videos, preferredItemEncoding: .current) {
                menuRow(
                    icon: "folder.fill",
                    title: CastHomeCopy.localVideosKey,
                    subtitle: localVideoManager.isImporting ? CastHomeCopy.importingKey : CastHomeCopy.importFromPhotosKey
                )
            }
            .buttonStyle(.plain)

            Divider().background(Color.dashBorder.opacity(0.6))

            // Row 3: Mirror iPhone
            Button {
                showingBroadcastPicker = true
            } label: {
                menuRow(
                    icon: "rectangle.on.rectangle.fill",
                    title: CastHomeCopy.mirrorIPhoneKey,
                    subtitle: CastHomeCopy.shareScreenLiveKey
                )
            }
            .buttonStyle(.plain)

            Divider().background(Color.dashBorder.opacity(0.6))

            // Row 4: Browser
            Button {
                showingWebBrowser = true
            } label: {
                menuRow(
                    icon: "globe",
                    title: CastHomeCopy.browserKey,
                    subtitle: CastHomeCopy.exploreWebsitesKey
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Cast_BrowserRow")
        }
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Imported local videos

    private var localVideosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(CastHomeCopy.yourVideosKey)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dashYellow)
                Spacer()
                if localVideoManager.isImporting {
                    ProgressView().tint(.dashYellow)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 1) {
                ForEach(localVideoManager.localVideos) { video in
                    HStack(spacing: 12) {
                        Button {
                            playerService.load(channel: video)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: playerService.currentChannel?.id == video.id ? "speaker.wave.2.fill" : "play.rectangle.fill")
                                    .foregroundStyle(Color.dashYellow)
                                Text(video.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            if playerService.currentChannel?.id == video.id {
                                playerService.stop()
                            }
                            localVideoManager.deleteVideo(video)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.dashTextMuted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(CastHomeCopy.deleteVideoAccessibilityLabel(video.name))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.dashSurface)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    private func menuRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.15, blue: 0.22))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.dashYellow)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.dashTextPrimary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextSecondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dashTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - CarPlay Connection Visual Section

    private var carPlayStatusSection: some View {
        VStack(spacing: 16) {
            // Visual hardware mockup: iPhone and Car Head Unit screen
            HStack(spacing: 20) {
                // iPhone silhouette
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.28, green: 0.32, blue: 0.40), lineWidth: 3)
                        .frame(width: 70, height: 125)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.08, green: 0.09, blue: 0.12))
                        )

                    VStack(spacing: 6) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 20, height: 3)

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.dashYellow)

                        Text(CastHomeCopy.dashCastBrandKey)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.dashTextSecondary)
                    }
                }

                // Wireless connection link symbol with waves
                VStack(spacing: 4) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(externalDisplay.isExternalDisplayConnected ? Color.dashGreen : Color.dashYellow)

                    Image(systemName: externalDisplay.isExternalDisplayConnected ? "link.circle.fill" : "link")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(externalDisplay.isExternalDisplayConnected ? Color.dashGreen : Color.dashYellow)

                    Image(systemName: "wave.3.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(externalDisplay.isExternalDisplayConnected ? Color.dashGreen : Color.dashYellow)
                }

                // Car Head Unit Dashboard Screen
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(red: 0.28, green: 0.32, blue: 0.40), lineWidth: 3.5)
                        .frame(width: 170, height: 110)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.07, green: 0.08, blue: 0.11))
                        )

                    if externalDisplay.isExternalDisplayConnected {
                        VStack(spacing: 6) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.dashGreen)
                            Text(CastHomeCopy.displayConnectedKey)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.dashGreen)
                        }
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "car.side.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.dashYellow.opacity(0.8))
                            Text(CastHomeCopy.carPlayScreenKey)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.dashTextMuted)
                        }
                    }
                }
            }
            .frame(height: 135)
            .padding(.top, 4)

            // Status Text
            VStack(spacing: 6) {
                Text(externalDisplay.isExternalDisplayConnected ? CastHomeCopy.externalDisplayConnectedKey : CastHomeCopy.noExternalDisplayKey)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.dashTextPrimary)

                Text(externalDisplay.isExternalDisplayConnected
                     ? CastHomeCopy.playingOnCarDisplayKey
                     : CastHomeCopy.connectToWatchInCarKey)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dashTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // AirPlay + Guide buttons
            HStack(spacing: 10) {
                Button {
                    showingCastGuide = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle")
                        Text(CastHomeCopy.helpKey)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dashYellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.dashYellow.opacity(0.12))
                    .clipShape(Capsule())
                }

                AirPlayRoutePickerRepresentable(tintColor: .dashYellow)
                    .frame(width: 36, height: 36)
                    .background(Color.dashSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.dashBorder, lineWidth: 1))
            }
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Playlists Sheet

    private var mediaSourcePlaylistsSheet: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // MARK: Section 1 - Media Servers (Jellyfin & Emby)
                        VStack(spacing: 10) {
                            HStack {
                                Text(CastHomeCopy.mediaServersSectionKey)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.dashYellow)
                                Spacer()
                                Button {
                                    showingAddServer = true
                                } label: {
                                    Label(CastHomeCopy.addServerKey, systemImage: "plus")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.dashYellow)
                                }
                                .accessibilityIdentifier("MediaSources_AddServerButton")
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)

                            if mediaServerStore.accounts.isEmpty {
                                Button {
                                    showingAddServer = true
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.dashSurfaceHighlight)
                                                .frame(width: 44, height: 44)

                                            Image(systemName: "server.rack")
                                                .font(.system(size: 20))
                                                .foregroundStyle(Color.dashYellow)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(CastHomeCopy.connectJellyfinEmbyKey)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(Color.dashTextPrimary)

                                            Text(CastHomeCopy.homeMediaServerSubtitleKey)
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.dashTextSecondary)
                                                .lineLimit(2)
                                        }

                                        Spacer()

                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.dashYellow)
                                    }
                                    .padding()
                                    .background(Color.dashSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("MediaSources_ConnectServer")
                            } else {
                                ForEach(mediaServerStore.accounts) { account in
                                    NavigationLink {
                                        MediaLibrariesView(account: account)
                                    } label: {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.dashSurfaceHighlight)
                                                    .frame(width: 44, height: 44)

                                                Image(systemName: "server.rack")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(Color.dashYellow)
                                            }

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(account.serverName)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(Color.dashTextPrimary)

                                                Text("\(account.kind.displayName) · \(account.username)")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.dashTextSecondary)
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.dashTextMuted)
                                        }
                                        .padding()
                                        .background(Color.dashSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("MediaSources_ServerRow_\(account.serverName)")
                                }

                                NavigationLink {
                                    MediaServersHomeView()
                                } label: {
                                    HStack {
                                        Spacer()
                                        Text(CastHomeCopy.manageAllServersKey)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.dashTextSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.dashTextMuted)
                                    }
                                    .padding(.horizontal)
                                }
                                .accessibilityIdentifier("MediaSources_ManageServers")
                            }
                        }

                        // MARK: Section 2 - Playlists & Channels (with QR Entry)
                        HStack {
                            Text(playlistStore.playlists.isEmpty ? CastHomeCopy.sampleStreamsKey : CastHomeCopy.yourChannelsKey)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.dashYellow)
                            Spacer()

                            Button {
                                showingQRScanner = true
                            } label: {
                                Label(CastHomeCopy.scanQRKey, systemImage: "qrcode.viewfinder")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.dashYellow)
                            }
                            .accessibilityIdentifier("MediaSources_ScanQRHeaderButton")

                            Menu {
                                Button {
                                    showingQRScanner = true
                                } label: {
                                    Label(CastHomeCopy.scanQRCodeKey, systemImage: "qrcode.viewfinder")
                                }
                                .accessibilityIdentifier("MediaSources_ScanQRMenu")

                                Button {
                                    showingAddM3UDialog = true
                                } label: {
                                    Label(CastHomeCopy.fromURLKey, systemImage: "link")
                                }
                                .accessibilityIdentifier("MediaSources_FromURLMenu")

                                Button {
                                    showingPlaylistFileImporter = true
                                } label: {
                                    Label(CastHomeCopy.fromFilesKey, systemImage: "folder")
                                }
                                .accessibilityIdentifier("MediaSources_FromFilesMenu")

                                Button {
                                    showingAddServer = true
                                } label: {
                                    Label(CastHomeCopy.connectJellyfinEmbyKey, systemImage: "server.rack")
                                }
                                .accessibilityIdentifier("MediaSources_AddServerMenu")

                                if !playlistStore.playlists.isEmpty {
                                    Button {
                                        Task { await playlistStore.refreshAll() }
                                    } label: {
                                        Label(CastHomeCopy.refreshAllKey, systemImage: "arrow.clockwise")
                                    }
                                }
                            } label: {
                                Text(CastHomeCopy.addSourceButtonKey)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.dashYellow)
                            }
                            .accessibilityIdentifier("MediaSources_AddSourceMenu")
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        if let importSuccessMessage {
                            Text(importSuccessMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.dashYellow)
                                .padding(.horizontal)
                        }

                        if playlistStore.playlists.isEmpty {
                            Button {
                                showingQRScanner = true
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.dashSurfaceHighlight)
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "qrcode.viewfinder")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.dashYellow)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(CastHomeCopy.scanPlaylistQRCodeKey)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.dashTextPrimary)

                                        Text(CastHomeCopy.scanQRPromptSubtitleKey)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.dashYellow)
                                }
                                .padding()
                                .background(Color.dashSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("MediaSources_ScanQRCard")
                        }

                        ForEach(playlistStore.playlists) { playlist in
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                    .foregroundStyle(Color.dashYellow)
                                Text(CastHomeCopy.playlistChannelCountKey(title: playlist.title, count: playlist.channels.count))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.dashTextSecondary)
                                Spacer()
                                Button(role: .destructive) {
                                    playlistStore.removePlaylist(id: playlist.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.dashTextMuted)
                                }
                            }
                            .padding(.horizontal)
                        }

                        ForEach(playlistStore.allChannels) { channel in
                            Button {
                                playerService.load(channel: channel)
                                showingPlaylistsSheet = false
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.dashSurfaceHighlight)
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "tv.fill")
                                            .foregroundStyle(Color.dashYellow)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(channel.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.dashTextPrimary)

                                        Text(channel.groupTitle)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }

                                    Spacer()

                                    Button {
                                        playlistStore.toggleFavorite(channel)
                                    } label: {
                                        Image(systemName: playlistStore.isFavorite(channel) ? "heart.fill" : "heart")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color.dashYellow)
                                    }
                                    .buttonStyle(.plain)

                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.dashYellow)
                                }
                                .padding()
                                .background(Color.dashSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("MediaSources_Channel")
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .sheet(isPresented: $showingAddM3UDialog) {
                addM3UDialogSheet
            }
            .sheet(isPresented: $showingAddServer) {
                AddMediaServerView()
            }
            .sheet(isPresented: $showingQRScanner) {
                PlaylistQRImportView()
            }
            .fileImporter(
                isPresented: $showingPlaylistFileImporter,
                allowedContentTypes: PlaylistStore.playlistContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        let playlist = try playlistStore.importPlaylist(fileURL: url)
                        importSuccessMessage = CastHomeCopy.importedChannelsMessage(count: playlist.channels.count, title: playlist.title)
                    } catch {
                        importErrorMessage = error.localizedDescription
                    }
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                }
            }
            .alert(CastHomeCopy.couldntImportPlaylistKey, isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )) {
                Button(CastHomeCopy.okKey, role: .cancel) { importErrorMessage = nil }
            } message: {
                Text(importErrorMessage ?? "")
            }
            .navigationTitle(CastHomeCopy.mediaSourcesKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(CastHomeCopy.doneKey) { showingPlaylistsSheet = false }
                        .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    private var favoritesSheet: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.dashTextMuted)
                    Text(CastHomeCopy.noFavoritesYetKey)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)
                    Text(CastHomeCopy.favoritesEmptySubtitleKey)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dashTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle(CastHomeCopy.favoritesTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(CastHomeCopy.closeKey) { showingFavorites = false }
                        .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    private var addM3UDialogSheet: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text(CastHomeCopy.addCustomStreamTitleKey)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    TextField(CastHomeCopy.playlistURLPlaceholderKey, text: $m3uURLInput)
                        .padding()
                        .background(Color.dashSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dashBorder, lineWidth: 1))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal)

                    Button {
                        loadM3UFromURL()
                    } label: {
                        Text(isImportingPlaylist ? CastHomeCopy.importingKey : CastHomeCopy.importPlaylistKey)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient.dashAccentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }

                    .disabled(isImportingPlaylist || CastHomeURLInputValidator.normalizedInput(m3uURLInput).isEmpty)

                    Text(CastHomeCopy.pasteStreamURLHintKey)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                        .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 30)
            }
            .navigationTitle(CastHomeCopy.addStreamTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(CastHomeCopy.cancelKey) { showingAddM3UDialog = false }
                        .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    private func loadM3UFromURL() {
        let input = CastHomeURLInputValidator.normalizedInput(m3uURLInput)
        isImportingPlaylist = true
        Task {
            defer { isImportingPlaylist = false }
            do {
                // A bare .m3u8 HLS stream is a single channel, not a channel list.
                if let url = URL(string: input), CastHomeURLInputValidator.isSingleHLSStreamURL(url),
                   let data = try? await URLSession.shared.data(from: url).0,
                   let text = IPTVParser.decode(data), text.contains("#EXT-X-") {
                    let channel = ChannelModel(name: url.deletingPathExtension().lastPathComponent,
                                               streamURL: url, groupTitle: "Streams")
                    let m3u = "#EXTM3U\n#EXTINF:-1 group-title=\"Streams\",\(channel.name)\n\(url.absoluteString)\n"
                    try playlistStore.addPlaylist(data: Data(m3u.utf8), sourceURL: nil, title: channel.name)
                    playerService.load(channel: channel)
                    importSuccessMessage = CastHomeCopy.addedStreamMessage(name: channel.name)
                } else {
                    let playlist = try await playlistStore.importPlaylist(from: input)
                    importSuccessMessage = CastHomeCopy.importedChannelsMessage(count: playlist.channels.count, title: playlist.title)
                }
                m3uURLInput = ""
                showingAddM3UDialog = false
            } catch {
                importErrorMessage = error.localizedDescription
                showingAddM3UDialog = false
            }
        }
    }
}
