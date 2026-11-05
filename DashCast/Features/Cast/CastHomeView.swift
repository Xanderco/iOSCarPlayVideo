import SwiftUI
import PhotosUI

/// Home: search, quick ways to watch, Continue Watching, Favorites, Recently Watched,
/// your sources and the car-display status. Playback continues in the mini player.
public struct CastHomeView: View {
    /// Identifiable wrapper so the Library sheet can open at a specific place.
    private struct LibraryLaunch: Identifiable {
        let id = UUID()
        let route: LibraryRoute?
    }

    @EnvironmentObject private var appState: AppState
    @ObservedObject private var player = VideoPlayerService.shared
    @ObservedObject private var presentation = PlayerPresentation.shared
    @ObservedObject private var playlistStore = PlaylistStore.shared
    @ObservedObject private var localVideos = LocalVideoManager.shared
    @ObservedObject private var history = WatchHistoryStore.shared
    @ObservedObject private var externalDisplay = ExternalDisplayManager.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var query = ""
    @State private var library: LibraryLaunch?
    @State private var showingAddSource = false
    @State private var showingWebBrowser = false
    @State private var showingGuide = false
    @State private var showingMirror = false
    @State private var showingPhotoPicker = false
    @State private var pickedPhotoItem: PhotosPickerItem?
    @State private var localImportError: String?

    public init() {}

    private var gridColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: DSSpacing.gridGap), count: count)
    }

    private var bottomInset: CGFloat {
        // Tab bar clearance, plus room for the mini player when it is showing.
        110 + (player.currentChannel != nil ? DSLayout.miniPlayerHeight + DSSpacing.sm : 0)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                    SearchField(text: $query, prompt: "Search all channels")
                        .accessibilityIdentifier("Home_Search")

                    if query.isEmpty {
                        quickActions
                        if playlistStore.playlists.isEmpty && localVideos.localVideos.isEmpty && history.entries.isEmpty {
                            welcome
                        }
                        continueWatching
                        favorites
                        recents
                        sources
                        carDisplayCard
                    } else {
                        searchResults
                    }
                }
                .padding(.top, DSSpacing.sm)
                .padding(.bottom, bottomInset)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.dcBackground.ignoresSafeArea())
            .navigationTitle("DashCast")
            .toolbar { toolbar }
        }
        .tint(Color.dcAccent)
        // The tab-level paywall can't present over these sheets, so they present it too (#24).
        .sheet(item: $library) { launch in
            LibraryView(initialRoute: launch.route)
                .sheet(isPresented: $appState.showPaywall) {
                    LifetimePaywallView().environmentObject(appState)
                }
        }
        .sheet(isPresented: $showingAddSource) {
            AddSourceSheet()
                .sheet(isPresented: $appState.showPaywall) {
                    LifetimePaywallView().environmentObject(appState)
                }
        }
        .sheet(isPresented: $showingGuide) { CarCastGuideModalView() }
        .sheet(isPresented: $showingWebBrowser) {
            WebVideoBrowserView()
                .sheet(isPresented: $appState.showPaywall) {
                    LifetimePaywallView().environmentObject(appState)
                }
        }
        .sheet(isPresented: $showingMirror) {
            // #25's car-output panel: AirPlay route status, parked-only guard, broadcast + CarPlay mirror (#28).
            CarDisplaySheet()
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $pickedPhotoItem,
                      matching: .videos, preferredItemEncoding: .current)
        .onChange(of: pickedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    let channel = try await localVideos.importVideo(from: item)
                    presentation.play(channel)
                } catch {
                    localImportError = error.localizedDescription
                }
                // Reset so picking the same video again still triggers onChange.
                pickedPhotoItem = nil
            }
        }
        .alert("Couldn't import video", isPresented: Binding(
            get: { localImportError != nil },
            set: { if !$0 { localImportError = nil } }
        )) {
            Button("OK", role: .cancel) { localImportError = nil }
        } message: {
            Text(localImportError ?? "")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !appState.isProLifetimeUnlocked {
                Button {
                    appState.showPaywall = true
                } label: {
                    Label("Pro", systemImage: "crown.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.dcPro)
                }
                .accessibilityLabel(Text("DashCast Pro"))
                .accessibilityIdentifier("Home_Pro")
            }
            Menu {
                Button("Playlist or Server", systemImage: "list.bullet.rectangle") { showingAddSource = true }
                Button("Video from Photos", systemImage: "photo.on.rectangle") { showingPhotoPicker = true }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(Text("Add"))
            .accessibilityIdentifier("Home_Add")
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        LazyVGrid(columns: gridColumns, spacing: DSSpacing.gridGap) {
            SourceTile(title: "Library", subtitle: "\(playlistStore.allChannels.count) channels",
                       systemImage: "square.stack.fill") {
                library = LibraryLaunch(route: nil)
            }
            .accessibilityIdentifier("Cast_MediaSourceRow")

            SourceTile(title: "Web Video", subtitle: "Send a page's video to the car",
                       systemImage: "safari.fill", tint: .dcInfo) {
                showingWebBrowser = true
            }
            .accessibilityIdentifier("Cast_BrowserRow")

            SourceTile(title: "Mirror Screen", subtitle: "AirPlay or a cable",
                       systemImage: "rectangle.on.rectangle", tint: .dcWarning) {
                showingMirror = true
            }
            .accessibilityIdentifier("Cast_MirrorRow")

            SourceTile(title: "Car Mode", subtitle: "Big buttons, landscape",
                       systemImage: "car.fill", tint: .dcPro) {
                presentation.openCarMode()
            }
            .accessibilityIdentifier("Cast_CarModeRow")
        }
        .padding(.horizontal, DSSpacing.screenGutter)
    }

    private var welcome: some View {
        EmptyStateView(
            systemImage: "play.tv",
            title: "Bring your own videos",
            message: "Add an M3U playlist, connect a Jellyfin or Emby server, or import videos from Photos. Nothing leaves your iPhone.",
            actionTitle: "Add a Source", action: { showingAddSource = true },
            secondaryActionTitle: "Play a demo video", secondaryAction: { library = LibraryLaunch(route: .samples) }
        )
        .dsCard()
        .padding(.horizontal, DSSpacing.screenGutter)
    }

    // MARK: - Shelves

    @ViewBuilder
    private var continueWatching: some View {
        let items = history.continueWatching
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                SectionHeader("Continue Watching")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DSSpacing.gridGap) {
                        ForEach(items) { entry in
                            ResumeCard(entry: entry) { presentation.play(entry.channel) }
                                .contextMenu {
                                    Button("Remove from Continue Watching", systemImage: "xmark") { history.remove(entry) }
                                }
                        }
                    }
                    .padding(.horizontal, DSSpacing.screenGutter)
                }
            }
        }
    }

    @ViewBuilder
    private var favorites: some View {
        let items = playlistStore.favoriteChannels
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                SectionHeader("Favorites", count: items.count) { library = LibraryLaunch(route: .favorites) }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: DSSpacing.gridGap) {
                        ForEach(items) { channel in
                            Button {
                                presentation.play(channel)
                            } label: {
                                VStack(spacing: DSSpacing.xs) {
                                    ChannelLogo(url: channel.logoURL, name: channel.name, size: 72)
                                        .overlay(alignment: .bottomTrailing) {
                                            if channel.streamURL == player.currentChannel?.streamURL {
                                                Image(systemName: "waveform")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(Color.dcOnAccent)
                                                    .padding(4)
                                                    .background(Color.dcAccent, in: Circle())
                                            }
                                        }
                                    Text(channel.name)
                                        .font(DSTypography.caption)
                                        .foregroundStyle(Color.dcTextPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 84)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(channel.name))
                            .accessibilityHint(Text("Plays this channel"))
                        }
                    }
                    .padding(.horizontal, DSSpacing.screenGutter)
                }
            }
        }
    }

    @ViewBuilder
    private var recents: some View {
        let items = Array(history.recents.prefix(5))
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                SectionHeader("Recently Watched", actionTitle: "Clear") { history.clear() }
                VStack(spacing: 0) {
                    ForEach(items) { entry in
                        Button {
                            presentation.play(entry.channel)
                        } label: {
                            ChannelRow(
                                title: entry.channel.name,
                                subtitle: entry.channel.groupTitle,
                                logoURL: entry.channel.logoURL,
                                isLive: entry.isLive && !entry.channel.streamURL.isFileURL,
                                isPlaying: entry.channel.streamURL == player.currentChannel?.streamURL,
                                isFavorite: playlistStore.isFavorite(entry.channel),
                                progress: entry.isResumable ? entry.progress : nil,
                                onToggleFavorite: { playlistStore.toggleFavorite(entry.channel) }
                            )
                            .padding(.horizontal, DSSpacing.md)
                        }
                        .buttonStyle(.plain)
                        if entry.id != items.last?.id {
                            Divider().overlay(Color.dcSeparator).padding(.leading, DSSpacing.md)
                        }
                    }
                }
                .dsCard(padding: 0)
                .padding(.horizontal, DSSpacing.screenGutter)
            }
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            SectionHeader("Your Sources", subtitle: "Playlists, servers and videos")
            LazyVGrid(columns: gridColumns, spacing: DSSpacing.gridGap) {
                ForEach(playlistStore.playlists) { playlist in
                    SourceTile(title: playlist.title,
                               subtitle: "\(playlist.channels.count) channels",
                               systemImage: "list.bullet.rectangle.portrait.fill",
                               badge: playlist.url == nil ? "FILE" : "M3U") {
                        library = LibraryLaunch(route: .playlist(playlist.id))
                    }
                }
                SourceTile(title: "On This iPhone",
                           subtitle: localVideos.isImporting ? "Importing…" : "\(localVideos.localVideos.count) videos",
                           systemImage: "iphone", tint: .dcInfo,
                           status: localVideos.isImporting ? .loading : .ready) {
                    library = LibraryLaunch(route: .onThisPhone)
                }
                SourceTile.add { showingAddSource = true }
            }
            .padding(.horizontal, DSSpacing.screenGutter)
        }
    }

    // MARK: - Car display

    private var carDisplayCard: some View {
        let connected = externalDisplay.isExternalDisplayConnected
        return VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: connected ? "checkmark.circle.fill" : "car.side")
                    .font(.system(.title2, weight: .semibold))
                    .foregroundStyle(connected ? Color.dcSuccess : Color.dcTextSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(connected ? "Car display connected" : "Not connected to a car display")
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)
                    Text(connected
                         ? "Video plays full screen on the connected display. For passengers, or while parked."
                         : "Use AirPlay or a USB-C / HDMI adapter. You can keep browsing on your iPhone.")
                        .font(DSTypography.footnote)
                        .foregroundStyle(Color.dcTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                AirPlayRoutePickerRepresentable(tintColor: .dcAccent)
                    .frame(width: DSLayout.minTapTarget, height: DSLayout.minTapTarget)
                    .accessibilityLabel(Text("Choose a screen"))
            }
            .accessibilityElement(children: .contain)

            HStack(spacing: DSSpacing.sm) {
                PrimaryButton("How to connect", systemImage: "questionmark.circle", kind: .secondary, size: .compact) {
                    showingGuide = true
                }
                PrimaryButton("Car display options", systemImage: "rectangle.on.rectangle", kind: .tertiary, size: .compact) {
                    showingMirror = true
                }
            }
        }
        .dsCard()
        .padding(.horizontal, DSSpacing.screenGutter)
        .accessibilityIdentifier("Home_CarDisplayCard")
    }

    // MARK: - Search

    @ViewBuilder
    private var searchResults: some View {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let results = (playlistStore.allChannels + localVideos.localVideos)
            .filter { $0.name.localizedCaseInsensitiveContains(needle) || $0.groupTitle.localizedCaseInsensitiveContains(needle) }
        if results.isEmpty {
            EmptyStateView(systemImage: "magnifyingglass", title: "No matches",
                           message: "Nothing called “\(needle)” in your sources yet.",
                           actionTitle: "Add a Source", action: { showingAddSource = true })
        } else {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                SectionHeader("Channels", count: results.count)
                LazyVStack(spacing: 0) {
                    ForEach(results.prefix(100)) { channel in
                        Button {
                            presentation.play(channel)
                        } label: {
                            ChannelRow(
                                channel: channel,
                                isLive: history.looksLive(channel),
                                isPlaying: channel.streamURL == player.currentChannel?.streamURL,
                                isFavorite: playlistStore.isFavorite(channel),
                                onToggleFavorite: { playlistStore.toggleFavorite(channel) }
                            )
                            .padding(.horizontal, DSSpacing.screenGutter)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Home_SearchResult")
                    }
                }
            }
        }
    }
}

/// 16:9 "Continue Watching" card with a resume progress bar.
private struct ResumeCard: View {
    let entry: WatchHistoryStore.Entry
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 220

    init(entry: WatchHistoryStore.Entry, action: @escaping () -> Void) {
        self.entry = entry
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                        .fill(Color.dcSurfaceRaised)
                    ChannelLogo(url: entry.channel.logoURL, name: entry.channel.name, size: 56)
                    Image(systemName: "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.dcOnAccent)
                        .frame(width: 40, height: 40)
                        .background(Color.dcAccent, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(DSSpacing.sm)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(alignment: .bottom) {
                    if let progress = entry.progress {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.dcStroke)
                                Capsule().fill(Color.dcAccent).frame(width: proxy.size.width * progress)
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.bottom, 6)
                    }
                }
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(entry.channel.name)
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)
                        .lineLimit(1)
                    Text("\(TimecodeFormatter.string(max(entry.duration - entry.position, 0))) left")
                        .font(DSTypography.footnote)
                        .foregroundStyle(Color.dcTextSecondary)
                }
            }
            .frame(width: width)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Resume \(entry.channel.name)"))
        .accessibilityValue(Text("\(Int(((entry.progress ?? 0) * 100).rounded())) percent watched"))
        .accessibilityAddTraits(.isButton)
    }
}

