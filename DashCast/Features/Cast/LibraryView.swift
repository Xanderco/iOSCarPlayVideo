import SwiftUI
import PhotosUI

/// Where the Library sheet should open.
public enum LibraryRoute: Hashable {
    /// Groups of one playlist.
    case playlist(UUID)
    /// Groups of the built-in sample streams.
    case samples
    /// Every group from every source.
    case everything
    /// The channels of one group (`nil` playlist = across all sources).
    case group(playlist: UUID?, name: String)
    case favorites
    case onThisPhone
}

/// Library: Sources → Groups → Channels, plus Favorites and videos on this iPhone.
public struct LibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playlistStore = PlaylistStore.shared
    @ObservedObject private var localVideos = LocalVideoManager.shared
    @ObservedObject private var history = WatchHistoryStore.shared
    @ObservedObject private var player = VideoPlayerService.shared

    @State private var path: [LibraryRoute]
    @State private var query = ""
    @State private var showingAddSource = false
    @State private var refreshingID: UUID?
    @State private var pendingRemoval: IPTVPlaylist?

    /// Number of channels previewed on the Library root before "Browse everything".
    private let previewLimit = 40

    public init(initialRoute: LibraryRoute? = nil) {
        _path = State(initialValue: initialRoute.map { [$0] } ?? [])
    }

    public var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                SearchField(text: $query, prompt: "Search channels and groups")
                    .padding(.vertical, DSSpacing.sm)
                List {
                    if query.isEmpty {
                        sourcesSection
                        channelsPreviewSection
                    } else {
                        searchResults
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(Color.dcBackground.ignoresSafeArea())
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .tint(Color.dcAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSource = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(Color.dcAccent)
                    .accessibilityLabel(Text("Add Source"))
                    .accessibilityIdentifier("Library_AddSource")
                }
            }
            .navigationDestination(for: LibraryRoute.self) { route in
                destination(for: route)
            }
            .sheet(isPresented: $showingAddSource) {
                AddSourceSheet()
            }
            .confirmationDialog(
                "Remove \(pendingRemoval?.title ?? "source")?",
                isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let playlist = pendingRemoval { playlistStore.removePlaylist(id: playlist.id) }
                    pendingRemoval = nil
                }
            } message: {
                Text("Its channels disappear from DashCast. You can add the link again any time.")
            }
        }
        .tint(Color.dcAccent)
    }

    // MARK: - Root sections

    private var sourcesSection: some View {
        Section {
            NavigationLink(value: LibraryRoute.favorites) {
                sourceLabel("Favorites", systemImage: "star.fill", tint: .dcPro,
                            detail: "\(playlistStore.favoriteChannels.count)")
            }
            NavigationLink(value: LibraryRoute.onThisPhone) {
                sourceLabel("On This iPhone", systemImage: "iphone", tint: .dcInfo,
                            detail: "\(localVideos.localVideos.count)")
            }
            ForEach(playlistStore.playlists) { playlist in
                NavigationLink(value: LibraryRoute.playlist(playlist.id)) {
                    sourceLabel(playlist.title, systemImage: "list.bullet.rectangle.portrait.fill", tint: .dcAccent,
                                detail: refreshingID == playlist.id ? nil : "\(playlist.channels.count)",
                                isLoading: refreshingID == playlist.id)
                }
                .swipeActions(edge: .trailing) {
                    Button("Remove", role: .destructive) { pendingRemoval = playlist }
                }
                .contextMenu {
                    if playlist.url != nil {
                        Button("Refresh", systemImage: "arrow.clockwise") { refresh(playlist) }
                    }
                    Button("Remove", systemImage: "trash", role: .destructive) { pendingRemoval = playlist }
                }
            }
            NavigationLink(value: LibraryRoute.samples) {
                sourceLabel("Sample Streams", systemImage: "sparkles.tv", tint: .dcTextSecondary,
                            detail: "\(playlistStore.sampleChannels.count)")
            }
            Button {
                showingAddSource = true
            } label: {
                Label("Add a Source", systemImage: "plus.circle.fill")
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dcAccent)
            }
        } header: {
            Text("Sources")
        }
        .listRowBackground(Color.dcSurface)
    }

    private var channelsPreviewSection: some View {
        Section {
            ForEach(playlistStore.allChannels.prefix(previewLimit)) { channel in
                channelButton(channel)
            }
            if playlistStore.allChannels.count > previewLimit {
                NavigationLink(value: LibraryRoute.everything) {
                    Text("Browse all \(playlistStore.allChannels.count) channels")
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcAccent)
                }
            }
        } header: {
            Text(playlistStore.playlists.isEmpty ? "Try a sample" : "Channels")
        }
        .listRowBackground(Color.dcSurface)
    }

    @ViewBuilder
    private var searchResults: some View {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let pool = playlistStore.allChannels + localVideos.localVideos
        let channels = pool.filter { $0.name.lowercased().contains(needle) }
        let groups = playlistStore.groupedChannels().filter { $0.group.lowercased().contains(needle) }

        if channels.isEmpty && groups.isEmpty {
            Section {
                Text("Nothing matches “\(query)”. Try a shorter word, or add another source.")
                    .font(DSTypography.callout)
                    .foregroundStyle(Color.dcTextSecondary)
            }
            .listRowBackground(Color.dcSurface)
        }
        if !groups.isEmpty {
            Section("Groups") {
                ForEach(groups.prefix(20), id: \.group) { group in
                    NavigationLink(value: LibraryRoute.group(playlist: nil, name: group.group)) {
                        groupLabel(group.group, channels: group.channels)
                    }
                }
            }
            .listRowBackground(Color.dcSurface)
        }
        if !channels.isEmpty {
            Section("Channels") {
                ForEach(channels.prefix(100)) { channel in
                    channelButton(channel)
                }
            }
            .listRowBackground(Color.dcSurface)
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(for route: LibraryRoute) -> some View {
        switch route {
        case .playlist(let id):
            if let playlist = playlistStore.playlists.first(where: { $0.id == id }) {
                GroupListView(title: playlist.title, playlistID: id, channels: playlist.channels,
                              onRefresh: { await refreshAsync(playlist) })
            } else {
                EmptyStateView.error(title: "Source removed", message: "This source is no longer in your library.")
            }
        case .samples:
            GroupListView(title: "Sample Streams", playlistID: nil, channels: playlistStore.sampleChannels)
        case .everything:
            GroupListView(title: "All Sources", playlistID: nil, channels: playlistStore.allChannels)
        case .group(let playlistID, let name):
            let source = playlistID.flatMap { id in playlistStore.playlists.first { $0.id == id }?.channels }
                ?? (playlistStore.allChannels + localVideos.localVideos)
            ChannelListView(title: name, channels: source.filter { $0.groupTitle == name })
        case .favorites:
            FavoritesListView()
        case .onThisPhone:
            LocalVideosListView()
        }
    }

    // MARK: - Pieces

    private func channelButton(_ channel: ChannelModel) -> some View {
        Button {
            PlayerPresentation.shared.play(channel, expand: false)
            dismiss()
        } label: {
            ChannelRow(
                channel: channel,
                isLive: history.looksLive(channel),
                isPlaying: channel.streamURL == player.currentChannel?.streamURL,
                isFavorite: playlistStore.isFavorite(channel),
                onToggleFavorite: { playlistStore.toggleFavorite(channel) }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("MediaSources_Channel")
    }

    private func sourceLabel(_ title: String, systemImage: String, tint: Color,
                             detail: String?, isLoading: Bool = false) -> some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dcTextPrimary)
                .lineLimit(1)
            Spacer()
            if isLoading {
                ProgressView()
            } else if let detail {
                Text(detail)
                    .font(DSTypography.numeric)
                    .foregroundStyle(Color.dcTextTertiary)
            }
        }
        .frame(minHeight: DSLayout.minTapTarget)
    }

    private func refresh(_ playlist: IPTVPlaylist) {
        Task { await refreshAsync(playlist) }
    }

    private func refreshAsync(_ playlist: IPTVPlaylist) async {
        guard let url = playlist.url else { return }
        refreshingID = playlist.id
        defer { refreshingID = nil }
        _ = try? await playlistStore.importPlaylist(from: url.absoluteString, title: playlist.title)
    }
}

/// Shared label for a group row: name, channel count and the first three logos.
func groupLabel(_ name: String, channels: [ChannelModel]) -> some View {
    HStack(spacing: DSSpacing.md) {
        HStack(spacing: -10) {
            ForEach(Array(channels.prefix(3).enumerated()), id: \.offset) { _, channel in
                ChannelLogo(url: channel.logoURL, name: channel.name, size: 30)
            }
        }
        .frame(minWidth: 50, alignment: .leading)
        Text(name)
            .font(DSTypography.headline)
            .foregroundStyle(Color.dcTextPrimary)
            .lineLimit(1)
        Spacer()
        Text("\(channels.count)")
            .font(DSTypography.numeric)
            .foregroundStyle(Color.dcTextTertiary)
    }
    .frame(minHeight: DSLayout.minTapTarget)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("\(name), \(channels.count) channels"))
}

// MARK: - Groups of a source

struct GroupListView: View {
    let title: String
    let playlistID: UUID?
    let channels: [ChannelModel]
    var onRefresh: (() async -> Void)? = nil

    @ObservedObject var playlistStore = PlaylistStore.shared
    @State var filter = ""

    private var groups: [(group: String, channels: [ChannelModel])] {
        let all = playlistStore.groupedChannels(channels)
        guard !filter.isEmpty else { return all }
        return all.filter { $0.group.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $filter, prompt: "Filter groups")
                .padding(.vertical, DSSpacing.sm)
            if channels.isEmpty {
                EmptyStateView(systemImage: "tray", title: "No channels yet",
                               message: "This source has no playable channels. Check the link or try refreshing.")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    if filter.isEmpty {
                        NavigationLink {
                            ChannelListView(title: "All Channels", channels: channels)
                        } label: {
                            groupLabel("All Channels", channels: channels)
                        }
                        .listRowBackground(Color.dcSurface)
                    }
                    ForEach(groups, id: \.group) { group in
                        NavigationLink(value: LibraryRoute.group(playlist: playlistID, name: group.group)) {
                            groupLabel(group.group, channels: group.channels)
                        }
                        .listRowBackground(Color.dcSurface)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await onRefresh?() }
            }
        }
        .background(Color.dcBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Channels of a group

struct ChannelListView: View {
    enum Sort: String, CaseIterable, Identifiable {
        case playlist = "Playlist Order"
        case name = "A–Z"
        case recent = "Recently Watched"
        var id: String { rawValue }
    }

    let title: String
    let channels: [ChannelModel]

    @Environment(\.dismiss) var dismiss
    @ObservedObject var playlistStore = PlaylistStore.shared
    @ObservedObject var history = WatchHistoryStore.shared
    @ObservedObject var player = VideoPlayerService.shared
    @State var sort: Sort = .playlist
    @State var filter = ""

    private var sorted: [ChannelModel] {
        var list = filter.isEmpty ? channels : channels.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        switch sort {
        case .playlist: break
        case .name: list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recent:
            list.sort {
                (history.entry(for: $0)?.lastWatched ?? .distantPast) > (history.entry(for: $1)?.lastWatched ?? .distantPast)
            }
        }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $filter, prompt: "Filter channels")
                .padding(.vertical, DSSpacing.sm)
            if channels.isEmpty {
                EmptyStateView(systemImage: "tv.slash", title: "This group has no playable channels")
                    .frame(maxHeight: .infinity)
            } else {
                List(sorted) { channel in
                    Button {
                        PlayerPresentation.shared.play(channel, expand: false)
                    } label: {
                        ChannelRow(
                            channel: channel,
                            isLive: history.looksLive(channel),
                            isPlaying: channel.streamURL == player.currentChannel?.streamURL,
                            isFavorite: playlistStore.isFavorite(channel),
                            onToggleFavorite: { playlistStore.toggleFavorite(channel) }
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.dcSurface)
                    .accessibilityIdentifier("Library_Channel")
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.dcBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel(Text("Sort channels"))
            }
        }
    }
}

// MARK: - Favorites

struct FavoritesListView: View {
    @ObservedObject var playlistStore = PlaylistStore.shared
    @ObservedObject var player = VideoPlayerService.shared
    @ObservedObject var history = WatchHistoryStore.shared

    var body: some View {
        Group {
            if playlistStore.favoriteChannels.isEmpty {
                EmptyStateView(systemImage: "star", title: "No favorites yet",
                               message: "Tap the star on any channel to keep it one tap away here, on Home and in Car Mode.")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(playlistStore.favoriteChannels) { channel in
                        Button {
                            PlayerPresentation.shared.play(channel, expand: false)
                        } label: {
                            ChannelRow(channel: channel,
                                       isLive: history.looksLive(channel),
                                       isPlaying: channel.streamURL == player.currentChannel?.streamURL,
                                       isFavorite: true,
                                       onToggleFavorite: { playlistStore.toggleFavorite(channel) })
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.dcSurface)
                        .swipeActions {
                            Button("Remove", role: .destructive) { playlistStore.toggleFavorite(channel) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.dcBackground.ignoresSafeArea())
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - On This iPhone

struct LocalVideosListView: View {
    @ObservedObject var localVideos = LocalVideoManager.shared
    @ObservedObject var player = VideoPlayerService.shared
    @ObservedObject var history = WatchHistoryStore.shared
    @State var showingPicker = false
    @State var pickedItem: PhotosPickerItem?
    @State var importError: String?

    var body: some View {
        Group {
            if localVideos.localVideos.isEmpty && !localVideos.isImporting {
                EmptyStateView(systemImage: "film.stack", title: "No videos on this iPhone yet",
                               message: "Import videos from Photos to watch them offline, on the road.",
                               actionTitle: "Import from Photos", action: { showingPicker = true })
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    if localVideos.isImporting {
                        HStack(spacing: DSSpacing.sm) {
                            ProgressView()
                            Text("Importing video…").foregroundStyle(Color.dcTextSecondary)
                        }
                        .listRowBackground(Color.dcSurface)
                    }
                    ForEach(localVideos.localVideos) { video in
                        Button {
                            PlayerPresentation.shared.play(video, expand: false)
                        } label: {
                            ChannelRow(title: video.name,
                                       subtitle: "On this iPhone",
                                       isPlaying: video.streamURL == player.currentChannel?.streamURL,
                                       progress: history.entry(for: video)?.progress)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.dcSurface)
                        .swipeActions {
                            Button("Delete", role: .destructive) { delete(video) }
                        }
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(video) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.dcBackground.ignoresSafeArea())
        .navigationTitle("On This iPhone")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingPicker = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text("Import from Photos"))
            }
        }
        .photosPicker(isPresented: $showingPicker, selection: $pickedItem, matching: .videos, preferredItemEncoding: .current)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    let channel = try await localVideos.importVideo(from: item)
                    PlayerPresentation.shared.play(channel, expand: false)
                } catch {
                    importError = error.localizedDescription
                }
                pickedItem = nil
            }
        }
        .alert("Couldn't import video", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private func delete(_ video: ChannelModel) {
        if player.currentChannel?.id == video.id { player.stop() }
        localVideos.deleteVideo(video)
    }
}
