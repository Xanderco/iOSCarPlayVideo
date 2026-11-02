import SwiftUI
import PhotosUI

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
    @State private var channels: [ChannelModel] = IPTVParser.samplePlaylist

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
            }
            .sheet(isPresented: $showingPlaylistsSheet) {
                mediaSourcePlaylistsSheet
            }
            .sheet(isPresented: $showingFavorites) {
                favoritesSheet
            }
            .sheet(isPresented: $showingAddM3UDialog) {
                addM3UDialogSheet
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

            // AirPlay & Guide buttons
            HStack(spacing: 12) {
                Button {
                    showingCastGuide = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("Connection Help")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dashYellow)
                    .padding(.horizontal, 14)
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
                            Text("Sample Automotive Streams")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.dashYellow)
                            Spacer()
                            Button("+ Add M3U URL") {
                                showingAddM3UDialog = true
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.dashYellow)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        ForEach(channels) { channel in
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
                        }
                    }
                    .padding(.bottom, 30)
                }
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

    private var favoritesSheet: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.dashTextMuted)
                    Text("No Favorites Yet")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)
                    Text("Save videos and web bookmarks to quickly access them in your car.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dashTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
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
                        .padding(.horizontal)

                    Button {
                        loadM3UFromURL()
                        showingAddM3UDialog = false
                    } label: {
                        Text("Import Stream")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient.dashAccentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }

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
        guard let url = URL(string: m3uURLInput) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let content = String(data: data, encoding: .utf8) {
                    let parsed = IPTVParser.parseM3U(content: content)
                    if !parsed.isEmpty {
                        self.channels.append(contentsOf: parsed)
                    }
                }
            } catch {
                print("Failed to download M3U: \(error)")
            }
        }
    }
}
