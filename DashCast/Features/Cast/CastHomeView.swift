import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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
    @State private var showingCarPlaySimulator: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isFullscreenPlayer: Bool = false
    @State private var m3uURLInput: String = ""
    @StateObject private var playlistStore = PlaylistStore.shared
    @State private var isImportingPlaylist: Bool = false
    @State private var showingPlaylistFileImporter: Bool = false
    @State private var importErrorMessage: String?
    @State private var importSuccessMessage: String?

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
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("Cast_MiniPlayer")
                        }

                        // Main 4-Row Source Menu Card (Exact 1:1 CarDash layout)
                        mainSourceMenuCard

                        // CarPlay Connection Illustration & Status Section
                        carPlayStatusSection
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 110) // clearance for LiquidCapsuleTabBar
                }
            }
            .navigationTitle("Cast")
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
                                    Text("PRO")
                                        .font(.system(size: 12, weight: .heavy))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(LinearGradient.dashProGoldGradient)
                                .foregroundStyle(Color.black)
                                .clipShape(Capsule())
                            }
                            .accessibilityIdentifier("Cast_ProButton")
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
                        .accessibilityIdentifier("Cast_HelpButton")

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
                        .accessibilityIdentifier("Cast_FavoritesButton")
                    }
                }
            }
            .sheet(isPresented: $showingCastGuide) {
                CarCastGuideModalView()
            }
            .sheet(isPresented: $showingWebBrowser) {
                WebVideoBrowserView()
            }
            .sheet(isPresented: $showingPlaylistsSheet) {
                mediaSourcePlaylistsSheet
            }
            .sheet(isPresented: $showingFavorites) {
                favoritesSheet
            }
            .sheet(isPresented: Binding(
                get: { showingCarPlaySimulator || appState.showCarPlaySimulator },
                set: {
                    showingCarPlaySimulator = $0
                    appState.showCarPlaySimulator = $0
                }
            )) {
                CarPlaySimulatorView()
            }
            .sheet(isPresented: $showingBroadcastPicker) {
                NavigationStack {
                    ZStack {
                        Color.dashBackground.ignoresSafeArea()
                        VStack(spacing: 24) {
                            Text("Mirror iPhone Screen")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.dashTextPrimary)

                            Text("Broadcast your entire iOS screen live to your car's CarPlay display via AirPlay.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.dashTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            ScreenBroadcastPickerView()
                                .frame(width: 80, height: 80)
                                .padding()
                                .background(Color.dashSurface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.dashYellow.opacity(0.4), lineWidth: 2))

                            AirPlayRoutePickerRepresentable(tintColor: .dashYellow)
                                .frame(width: 50, height: 50)

                            Spacer()
                        }
                        .padding(.top, 40)
                    }
                    .navigationTitle("Screen Mirroring")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showingBroadcastPicker = false }
                                .foregroundStyle(Color.dashYellow)
                        }
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { (newItem: PhotosPickerItem?) in
                guard let newItem = newItem else { return }
                Task {
                    await localVideoManager.importVideo(from: newItem)
                }
            }
        }
    }

    // MARK: - 4-Row Source Menu Card

    private var mainSourceMenuCard: some View {
        VStack(spacing: 1) {
            // Row 1: Media Source
            Button {
                showingPlaylistsSheet = true
            } label: {
                menuRow(
                    icon: "play.tv.fill",
                    title: "Media Source",
                    subtitle: "Your M3U / M3U8 playlists"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Cast_MediaSourceRow")

            Divider().background(Color.dashBorder.opacity(0.6))

            // Row 2: Local Videos
            PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
                menuRow(
                    icon: "folder.fill",
                    title: "Local Videos",
                    subtitle: "From Photos & Files"
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
                    title: "Mirror iPhone",
                    subtitle: "Share your screen live"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Cast_MirrorRow")

            Divider().background(Color.dashBorder.opacity(0.6))

            // Row 4: Browser
            Button {
                showingWebBrowser = true
            } label: {
                menuRow(
                    icon: "globe",
                    title: "Browser",
                    subtitle: "Explore websites"
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

    private func menuRow(icon: String, title: String, subtitle: String) -> some View {
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

                        Text("DashCast")
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
                            Text("CarPlay Connected")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.dashGreen)
                        }
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "car.side.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.dashYellow.opacity(0.8))
                            Text("CarPlay Screen")
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
                Text(externalDisplay.isExternalDisplayConnected ? "CarPlay Connected" : "CarPlay not connected")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.dashTextPrimary)

                Text(externalDisplay.isExternalDisplayConnected
                     ? "Playing video & audio on car display while parked."
                     : "Connect to watch in your car. You can still explore on iPhone.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dashTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // AirPlay, Guide & CarPlay Mode Simulator buttons
            HStack(spacing: 10) {
                Button {
                    showingCarPlaySimulator = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "car.side.fill")
                        Text("CarPlay Mode")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(LinearGradient.dashAccentGradient)
                    .clipShape(Capsule())
                    .shadow(color: Color.dashYellow.opacity(0.35), radius: 6, y: 3)
                }
                .accessibilityIdentifier("Cast_CarPlayModeButton")

                Button {
                    showingCastGuide = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle")
                        Text("Help")
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
                        HStack {
                            Text(playlistStore.playlists.isEmpty ? "Sample Streams" : "Your Channels")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.dashYellow)
                            Spacer()
                            Menu("+ Add Playlist") {
                                Button("From URL", systemImage: "link") { showingAddM3UDialog = true }
                                Button("From Files", systemImage: "folder") { showingPlaylistFileImporter = true }
                                if !playlistStore.playlists.isEmpty {
                                    Button("Refresh All", systemImage: "arrow.clockwise") {
                                        Task { await playlistStore.refreshAll() }
                                    }
                                }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.dashYellow)
                            .accessibilityIdentifier("MediaSources_AddMenu")
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        if let importSuccessMessage {
                            Text(importSuccessMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.dashYellow)
                                .padding(.horizontal)
                                .accessibilityIdentifier("MediaSources_ImportSuccess")
                        }

                        ForEach(playlistStore.playlists) { playlist in
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                    .foregroundStyle(Color.dashYellow)
                                Text("\(playlist.title) · \(playlist.channels.count) channels")
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
                            channelRow(channel) {
                                playerService.load(channel: channel)
                                showingPlaylistsSheet = false
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .sheet(isPresented: $showingAddM3UDialog) {
                addM3UDialogSheet
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
                        importSuccessMessage = "Imported \(playlist.channels.count) channels from \(playlist.title)"
                    } catch {
                        importErrorMessage = error.localizedDescription
                    }
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                }
            }
            .alert("Couldn't import playlist", isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { importErrorMessage = nil }
            } message: {
                Text(importErrorMessage ?? "")
            }
            .navigationTitle("Media Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { showingPlaylistsSheet = false }
                        .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    /// One playable channel row with a separate favorite toggle. The two buttons are siblings
    /// (not nested) so VoiceOver and UI tests can reach the heart independently.
    private func channelRow(_ channel: ChannelModel, onPlay: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Button(action: onPlay) {
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

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.dashYellow)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(channel.name)
            .accessibilityIdentifier("MediaSources_Channel")

            Button {
                playlistStore.toggleFavorite(channel)
            } label: {
                Image(systemName: playlistStore.isFavorite(channel) ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.dashYellow)
                    .frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playlistStore.isFavorite(channel) ? "Remove \(channel.name) from favorites" : "Add \(channel.name) to favorites")
            .accessibilityValue(playlistStore.isFavorite(channel) ? "favorite" : "not favorite")
            .accessibilityIdentifier("Channel_FavoriteButton")
        }
        .padding()
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var favoritesSheet: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()
                if playlistStore.favoriteChannels.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.dashTextMuted)
                        Text("No Favorites Yet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                        Text("Tap the heart on any channel in Media Source to keep it here and in CarPlay.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dashTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Favorites_Empty")
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(playlistStore.favoriteChannels) { channel in
                                channelRow(channel) {
                                    playerService.load(channel: channel)
                                    showingFavorites = false
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { showingFavorites = false }
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
                    Text("Add Custom M3U / M3U8 Stream")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    TextField("https://example.com/playlist.m3u", text: $m3uURLInput)
                        .padding()
                        .background(Color.dashSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dashBorder, lineWidth: 1))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(.horizontal)
                        .accessibilityIdentifier("AddStream_URLField")

                    Button {
                        loadM3UFromURL()
                    } label: {
                        Text(isImportingPlaylist ? "Importing…" : "Import Playlist")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient.dashAccentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }

                    .disabled(isImportingPlaylist || m3uURLInput.isEmpty)
                    .accessibilityIdentifier("AddStream_ImportButton")

                    Text("Paste an M3U / M3U8 playlist link or a single HLS stream URL.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                        .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 30)
            }
            .navigationTitle("Add Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingAddM3UDialog = false }
                        .foregroundStyle(Color.dashYellow)
                }
            }
        }
    }

    private func loadM3UFromURL() {
        let input = m3uURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        isImportingPlaylist = true
        Task {
            defer { isImportingPlaylist = false }
            do {
                // A bare .m3u8 HLS stream is a single channel, not a channel list.
                if let url = URL(string: input), url.pathExtension.lowercased() == "m3u8",
                   let data = try? await URLSession.shared.data(from: url).0,
                   let text = IPTVParser.decode(data), text.contains("#EXT-X-") {
                    let channel = ChannelModel(name: url.deletingPathExtension().lastPathComponent,
                                               streamURL: url, groupTitle: "Streams")
                    let m3u = "#EXTM3U\n#EXTINF:-1 group-title=\"Streams\",\(channel.name)\n\(url.absoluteString)\n"
                    try playlistStore.addPlaylist(data: Data(m3u.utf8), sourceURL: nil, title: channel.name)
                    playerService.load(channel: channel)
                    importSuccessMessage = "Added stream \(channel.name)"
                } else {
                    let playlist = try await playlistStore.importPlaylist(from: input)
                    importSuccessMessage = "Imported \(playlist.channels.count) channels from \(playlist.title)"
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
