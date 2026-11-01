import SwiftUI
import PhotosUI

public struct CastHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var playerService = VideoPlayerService.shared
    @StateObject private var localVideoManager = LocalVideoManager.shared
    @StateObject private var externalDisplay = ExternalDisplayManager.shared

    @State private var selectedCategory: String = "All"
    @State private var channels: [ChannelModel] = IPTVParser.samplePlaylist
    @State private var showingAddM3UDialog: Bool = false
    @State private var m3uURLInput: String = ""
    @State private var showingWebBrowser: Bool = false
    @State private var showingCastGuide: Bool = false
    @State private var showingMetrics: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isFullscreenPlayer: Bool = false

    private let categories = ["All", "Movies", "Live", "Sports", "Local"]

    public init() {}

    public var filteredChannels: [ChannelModel] {
        if selectedCategory == "All" {
            return channels + localVideoManager.localVideos
        } else if selectedCategory == "Local" {
            return localVideoManager.localVideos
        } else {
            return channels.filter { $0.groupTitle.lowercased() == selectedCategory.lowercased() }
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Top Video Player Section
                        AutomotiveVideoPlayerView(isFullscreen: $isFullscreenPlayer)
                            .frame(height: 220)
                            .padding(.horizontal)

                        // Connected display banner if car screen is detected
                        if externalDisplay.isExternalDisplayConnected {
                            carConnectedBanner
                        }

                        // Quick Actions Bar
                        quickActionsBar

                        // Category Filter Pills
                        categoryFilterBar

                        // Keep Watching Carousel
                        if !channels.isEmpty {
                            keepWatchingSection
                        }

                        // Channels Grid
                        channelsSection
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Cast")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingMetrics = true
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.dashCyan)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !appState.isProLifetimeUnlocked {
                        Button {
                            appState.showPaywall = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(Color.dashGold)
                                Text("LIFETIME")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.dashGold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.dashGold.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .alert("Add M3U Playlist", isPresented: $showingAddM3UDialog) {
                TextField("https://example.com/playlist.m3u", text: $m3uURLInput)
                    .textInputAutocapitalization(.never)
                Button("Add") {
                    loadM3UFromURL()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a public or personal M3U / M3U8 streaming playlist URL.")
            }
            .sheet(isPresented: $showingWebBrowser) {
                WebVideoBrowserView()
            }
            .sheet(isPresented: $showingCastGuide) {
                CarCastGuideModalView()
            }
            .sheet(isPresented: $showingMetrics) {
                UsageMetricsView()
            }
            .fullScreenCover(isPresented: $isFullscreenPlayer) {
                AutomotiveVideoPlayerView(isFullscreen: $isFullscreenPlayer)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                if let newItem {
                    Task {
                        await localVideoManager.importVideo(from: newItem)
                    }
                }
            }
        }
    }

    private var carConnectedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "car.side.fill")
                .foregroundStyle(Color.dashGreen)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("Connected to Car Display")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("Playing video on external screen while parked")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dashTextSecondary)
            }

            Spacer()

            Circle()
                .fill(Color.dashGreen)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(Color.dashGreen.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var quickActionsBar: some View {
        HStack(spacing: 12) {
            actionButton(icon: "plus.circle.fill", label: "Add M3U") {
                if !appState.isProLifetimeUnlocked && channels.count > 10 {
                    appState.showPaywall = true
                } else {
                    showingAddM3UDialog = true
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.dashCyan)
                    Text("Import")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.dashTextPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.dashSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            actionButton(icon: "safari.fill", label: "Browser") {
                showingWebBrowser = true
            }

            // Cast to Car Button
            actionButton(icon: "airplayvideo", label: "Cast to Car") {
                showingCastGuide = true
            }
        }
        .padding(.horizontal)
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.dashCyan)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dashTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = cat
                        }
                    } label: {
                        Text(cat)
                            .font(.system(size: 14, weight: selectedCategory == cat ? .bold : .medium))
                            .foregroundStyle(selectedCategory == cat ? Color.black : Color.dashTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == cat
                                ? AnyView(LinearGradient.dashAccentGradient)
                                : AnyView(Color.dashSurface)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var keepWatchingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keep Watching")
                .font(ThemeFonts.hudTitle(size: 18))
                .foregroundStyle(Color.dashTextPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(channels.prefix(4)) { channel in
                        Button {
                            playerService.load(channel: channel)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.dashSurfaceHighlight)
                                        .frame(width: 170, height: 100)

                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 34))
                                        .foregroundStyle(Color.dashCyan)
                                }

                                Text(channel.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                    .lineLimit(1)

                                Text(channel.groupTitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.dashTextSecondary)
                            }
                            .frame(width: 170)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedCategory == "All" ? "All Channels & Videos" : "\(selectedCategory) Channels")
                    .font(ThemeFonts.hudTitle(size: 18))
                    .foregroundStyle(Color.dashTextPrimary)

                Spacer()

                Text("\(filteredChannels.count) items")
                    .font(ThemeFonts.hudCaption(size: 13))
                    .foregroundStyle(Color.dashTextMuted)
            }
            .padding(.horizontal)

            LazyVStack(spacing: 10) {
                ForEach(filteredChannels) { channel in
                    Button {
                        playerService.load(channel: channel)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.dashSurfaceHighlight)
                                    .frame(width: 46, height: 46)

                                Image(systemName: "tv.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.dashCyan)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(channel.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                    .lineLimit(1)

                                Text(channel.groupTitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.dashTextSecondary)
                            }

                            Spacer()

                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.dashCyan)
                        }
                        .padding()
                        .background(Color.dashSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal)
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
