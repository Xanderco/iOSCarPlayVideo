import SwiftUI
import AVKit

/// Localized copy keys and formatting helpers for `MediaServerViews`.
public enum MediaServerViewsCopy {
    nonisolated public static let mediaServersTitleString = "Media Servers"
    nonisolated public static let jellyfinEmbyHeaderString = "Jellyfin & Emby"
    nonisolated public static let emptyServersPromptString = "Connect a Jellyfin or Emby server to browse and play your own movies and shows."
    nonisolated public static let addServerString = "Add Server"
    nonisolated public static let scanPlaylistQRCodeString = "Scan Playlist QR Code"
    nonisolated public static let playlistsHeaderString = "Playlists"
    nonisolated public static let playlistsFooterString = "Scan a QR code containing an M3U / M3U8 playlist link to add it to your channels."
    nonisolated public static let doneString = "Done"
    nonisolated public static let serverSectionString = "Server"
    nonisolated public static let typeString = "Type"
    nonisolated public static let accountSectionString = "Account"
    nonisolated public static let usernameString = "Username"
    nonisolated public static let passwordString = "Password"
    nonisolated public static let connectString = "Connect"
    nonisolated public static let keychainFooterString = "Your access token is stored securely in the iOS Keychain. Your password is never saved."
    nonisolated public static let cancelString = "Cancel"
    nonisolated public static let continueWatchingString = "Continue Watching"
    nonisolated public static let librariesString = "Libraries"
    nonisolated public static let nothingHereYetString = "Nothing here yet"
    nonisolated public static let playFallbackString = "Play"
    nonisolated public static let resumeFromFormatString = "Resume from %@"
    nonisolated public static let startFromBeginningString = "Start from Beginning"
    nonisolated public static let playbackFailedString = "Playback Failed"
    nonisolated public static let okString = "OK"
    nonisolated public static let closePlayerString = "Close player"

    nonisolated public static let allLocalizationKeys: [String] = [
        mediaServersTitleString,
        jellyfinEmbyHeaderString,
        emptyServersPromptString,
        addServerString,
        scanPlaylistQRCodeString,
        playlistsHeaderString,
        playlistsFooterString,
        doneString,
        serverSectionString,
        typeString,
        accountSectionString,
        usernameString,
        passwordString,
        connectString,
        keychainFooterString,
        cancelString,
        continueWatchingString,
        librariesString,
        nothingHereYetString,
        playFallbackString,
        resumeFromFormatString,
        startFromBeginningString,
        playbackFailedString,
        okString,
        closePlayerString
    ]

    @MainActor public static var mediaServersTitleKey: LocalizedStringKey { LocalizedStringKey(mediaServersTitleString) }
    @MainActor public static var jellyfinEmbyHeaderKey: LocalizedStringKey { LocalizedStringKey(jellyfinEmbyHeaderString) }
    @MainActor public static var emptyServersPromptKey: LocalizedStringKey { LocalizedStringKey(emptyServersPromptString) }
    @MainActor public static var addServerKey: LocalizedStringKey { LocalizedStringKey(addServerString) }
    @MainActor public static var scanPlaylistQRCodeKey: LocalizedStringKey { LocalizedStringKey(scanPlaylistQRCodeString) }
    @MainActor public static var playlistsHeaderKey: LocalizedStringKey { LocalizedStringKey(playlistsHeaderString) }
    @MainActor public static var playlistsFooterKey: LocalizedStringKey { LocalizedStringKey(playlistsFooterString) }
    @MainActor public static var doneKey: LocalizedStringKey { LocalizedStringKey(doneString) }
    @MainActor public static var serverSectionKey: LocalizedStringKey { LocalizedStringKey(serverSectionString) }
    @MainActor public static var typeKey: LocalizedStringKey { LocalizedStringKey(typeString) }
    @MainActor public static var accountSectionKey: LocalizedStringKey { LocalizedStringKey(accountSectionString) }
    @MainActor public static var usernameKey: LocalizedStringKey { LocalizedStringKey(usernameString) }
    @MainActor public static var passwordKey: LocalizedStringKey { LocalizedStringKey(passwordString) }
    @MainActor public static var connectKey: LocalizedStringKey { LocalizedStringKey(connectString) }
    @MainActor public static var keychainFooterKey: LocalizedStringKey { LocalizedStringKey(keychainFooterString) }
    @MainActor public static var cancelKey: LocalizedStringKey { LocalizedStringKey(cancelString) }
    @MainActor public static var continueWatchingKey: LocalizedStringKey { LocalizedStringKey(continueWatchingString) }
    @MainActor public static var librariesKey: LocalizedStringKey { LocalizedStringKey(librariesString) }
    @MainActor public static var nothingHereYetKey: LocalizedStringKey { LocalizedStringKey(nothingHereYetString) }
    @MainActor public static var playFallbackKey: LocalizedStringKey { LocalizedStringKey(playFallbackString) }
    @MainActor public static var startFromBeginningKey: LocalizedStringKey { LocalizedStringKey(startFromBeginningString) }
    @MainActor public static var playbackFailedKey: LocalizedStringKey { LocalizedStringKey(playbackFailedString) }
    @MainActor public static var okKey: LocalizedStringKey { LocalizedStringKey(okString) }
    @MainActor public static var closePlayerKey: LocalizedStringKey { LocalizedStringKey(closePlayerString) }

    nonisolated public static func resumeTitleString(seconds: Double, bundle: Bundle = .main) -> String {
        let formattedTime = MediaTimeFormat.string(seconds)
        let format = String(localized: String.LocalizationValue(resumeFromFormatString), bundle: bundle)
        return String(format: format, formattedTime)
    }

    @MainActor
    public static func resumeTitleKey(seconds: Double) -> LocalizedStringKey {
        LocalizedStringKey("Resume from \(MediaTimeFormat.string(seconds))")
    }
}

// MARK: - Entry point

/// Root of the media-server feature: saved Jellyfin / Emby servers plus QR playlist import.
public struct MediaServersHomeView: View {
    @StateObject private var store = MediaServerStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddServer = false
    @State private var showingQRScanner = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.accounts.isEmpty {
                        Text(MediaServerViewsCopy.emptyServersPromptKey)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.accounts) { account in
                        NavigationLink {
                            MediaLibrariesView(account: account)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "server.rack")
                                    .foregroundStyle(Color.dashYellow)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.serverName).font(.headline)
                                    Text("\(account.kind.displayName) · \(account.username)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("mediaServerRow_\(account.serverName)")
                    }
                    .onDelete { offsets in
                        let doomed = offsets.map { store.accounts[$0] }
                        for account in doomed { store.remove(account) }
                    }
                    Button {
                        showingAddServer = true
                    } label: {
                        Label(MediaServerViewsCopy.addServerKey, systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("addMediaServerButton")
                } header: {
                    Text(MediaServerViewsCopy.jellyfinEmbyHeaderKey)
                }

                Section {
                    Button {
                        showingQRScanner = true
                    } label: {
                        Label(MediaServerViewsCopy.scanPlaylistQRCodeKey, systemImage: "qrcode.viewfinder")
                    }
                    .accessibilityIdentifier("scanPlaylistQRButton")
                } header: {
                    Text(MediaServerViewsCopy.playlistsHeaderKey)
                } footer: {
                    Text(MediaServerViewsCopy.playlistsFooterKey)
                }
            }
            .navigationTitle(MediaServerViewsCopy.mediaServersTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MediaServerViewsCopy.doneKey) { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                AddMediaServerView()
            }
            .sheet(isPresented: $showingQRScanner) {
                PlaylistQRImportView()
            }
        }
        .tint(Color.dashYellow)
    }
}

// MARK: - Add server

public struct AddMediaServerView: View {
    @StateObject private var store = MediaServerStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var kind: MediaServerKind = .jellyfin
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    public init() {}

    private var canSubmit: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !isConnecting
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(MediaServerViewsCopy.serverSectionKey) {
                    Picker(MediaServerViewsCopy.typeKey, selection: $kind) {
                        ForEach(MediaServerKind.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("http://192.168.1.10:8096", text: $address)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("mediaServerAddressField")
                }
                Section(MediaServerViewsCopy.accountSectionKey) {
                    TextField(MediaServerViewsCopy.usernameKey, text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("mediaServerUsernameField")
                    SecureField(MediaServerViewsCopy.passwordKey, text: $password)
                        .textContentType(.password)
                        .accessibilityIdentifier("mediaServerPasswordField")
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button {
                        Task { await connect() }
                    } label: {
                        HStack {
                            Spacer()
                            if isConnecting { ProgressView() } else { Text(MediaServerViewsCopy.connectKey).bold() }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("mediaServerConnectButton")
                } footer: {
                    Text(MediaServerViewsCopy.keychainFooterKey)
                }
            }
            .navigationTitle(MediaServerViewsCopy.addServerKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MediaServerViewsCopy.cancelKey) { dismiss() }
                }
            }
        }
    }

    private func connect() async {
        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }
        do {
            try await store.signIn(kind: kind,
                                   serverAddress: address,
                                   username: username.trimmingCharacters(in: .whitespaces),
                                   password: password)
            password = ""
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Libraries

struct MediaLibrariesView: View {
    let account: MediaServerAccount
    @State private var client: MediaServerClient?
    @State private var libraries: [MediaItem] = []
    @State private var resume: [MediaItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var playRequest: MediaItem?

    var body: some View {
        List {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            if let client, !resume.isEmpty {
                Section(MediaServerViewsCopy.continueWatchingKey) {
                    ForEach(resume) { item in
                        Button {
                            playRequest = item
                        } label: {
                            MediaItemRow(item: item, client: client)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let client {
                Section(MediaServerViewsCopy.librariesKey) {
                    ForEach(libraries) { library in
                        NavigationLink {
                            MediaItemGridView(account: account, client: client, parent: library)
                        } label: {
                            Label(library.name, systemImage: Self.icon(for: library.collectionType))
                        }
                    }
                }
            }
        }
        .overlay { if isLoading && libraries.isEmpty { ProgressView() } }
        .navigationTitle(account.serverName)
        .task { await load() }
        .refreshable { await load() }
        .modifier(MediaPlayLauncher(account: account, client: client, request: $playRequest))
    }

    static func icon(for collectionType: String?) -> String {
        switch collectionType {
        case "movies": return "film"
        case "tvshows": return "tv"
        case "music": return "music.note"
        case "homevideos": return "video"
        default: return "folder"
        }
    }

    private func load() async {
        let client = self.client ?? MediaServerStore.shared.client(for: account)
        self.client = client
        isLoading = true
        defer { isLoading = false }
        do {
            libraries = try await client.libraries()
            resume = (try? await client.resumeItems()) ?? []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Item grid

struct MediaItemGridView: View {
    let account: MediaServerAccount
    let client: MediaServerClient
    let parent: MediaItem

    @State private var items: [MediaItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var playRequest: MediaItem?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        ScrollView {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .padding()
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    if item.isSeries {
                        NavigationLink {
                            MediaSeriesView(account: account, client: client, series: item)
                        } label: {
                            MediaPosterCell(item: item, client: client)
                        }
                        .buttonStyle(.plain)
                    } else if item.isFolder {
                        NavigationLink {
                            MediaItemGridView(account: account, client: client, parent: item)
                        } label: {
                            MediaPosterCell(item: item, client: client)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            playRequest = item
                        } label: {
                            MediaPosterCell(item: item, client: client)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .overlay {
            if isLoading && items.isEmpty {
                ProgressView()
            } else if !isLoading && items.isEmpty && errorMessage == nil {
                Text(MediaServerViewsCopy.nothingHereYetKey).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(parent.name)
        .task { await load() }
        .refreshable { await load() }
        .modifier(MediaPlayLauncher(account: account, client: client, request: $playRequest))
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let types = parent.isFolder ? ["Movie", "Series", "Video", "MusicVideo", "Folder", "BoxSet"]
                                        : ["Movie", "Series", "Video", "MusicVideo"]
            items = try await client.items(parentId: parent.id, includeItemTypes: types)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MediaPosterCell: View {
    let item: MediaItem
    let client: MediaServerClient

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: client.imageURL(for: item, maxWidth: 300)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Color.dashSurfaceHighlight
                    Image(systemName: item.isSeries ? "tv" : "film")
                        .font(.title)
                        .foregroundStyle(Color.dashTextMuted)
                }
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .bottom) { MediaProgressBar(item: item) }

            Text(item.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            if let year = item.productionYear {
                Text(String(year)).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct MediaProgressBar: View {
    let item: MediaItem

    var body: some View {
        if let total = item.runtimeSeconds, total > 0, item.resumePositionSeconds > 0 {
            GeometryReader { geo in
                Capsule()
                    .fill(Color.dashYellow)
                    .frame(width: geo.size.width * min(1, item.resumePositionSeconds / total), height: 3)
            }
            .frame(height: 3)
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
    }
}

struct MediaItemRow: View {
    let item: MediaItem
    let client: MediaServerClient

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: client.imageURL(for: item, maxWidth: 200)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.dashSurfaceHighlight
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .bottom) { MediaProgressBar(item: item) }

            VStack(alignment: .leading, spacing: 2) {
                if let label = item.episodeLabel {
                    Text(label).font(.caption2.weight(.bold)).foregroundStyle(Color.dashYellow)
                }
                Text(item.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                if let series = item.seriesName {
                    Text(series).font(.caption).foregroundStyle(.secondary)
                } else if let runtime = item.runtimeSeconds {
                    Text(MediaTimeFormat.string(runtime)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if item.userData?.played == true {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Series → seasons → episodes

struct MediaSeriesView: View {
    let account: MediaServerAccount
    let client: MediaServerClient
    let series: MediaItem

    @State private var seasons: [MediaItem] = []
    @State private var episodes: [MediaItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var playRequest: MediaItem?

    var body: some View {
        List {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            if let overview = series.overview, !overview.isEmpty {
                Text(overview).font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(MediaSeasonGroup.group(episodes: episodes, seasons: seasons)) { group in
                Section(group.title) {
                    ForEach(group.episodes) { episode in
                        Button {
                            playRequest = episode
                        } label: {
                            MediaItemRow(item: episode, client: client)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay { if isLoading && episodes.isEmpty { ProgressView() } }
        .navigationTitle(series.name)
        .task { await load() }
        .refreshable { await load() }
        .modifier(MediaPlayLauncher(account: account, client: client, request: $playRequest))
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let seasonList = client.seasons(seriesId: series.id)
            async let episodeList = client.episodes(seriesId: series.id)
            let (s, e) = try await (seasonList, episodeList)
            seasons = s
            episodes = e
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Playback

enum MediaTimeFormat {
    static func string(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Asks "Resume / Start over" when needed, starts playback and shows the player.
struct MediaPlayLauncher: ViewModifier {
    let account: MediaServerAccount
    let client: MediaServerClient?
    @Binding var request: MediaItem?

    @State private var showResumeDialog = false
    @State private var showPlayer = false
    @State private var errorMessage: String?

    @MainActor
    static func dialogTitle(itemName: String?) -> Text {
        if let itemName, !itemName.isEmpty {
            return Text(verbatim: itemName)
        }
        return Text(MediaServerViewsCopy.playFallbackKey)
    }

    @MainActor
    static func resumeTitleKey(seconds: Double) -> LocalizedStringKey {
        MediaServerViewsCopy.resumeTitleKey(seconds: seconds)
    }

    nonisolated static func resumeTitleString(seconds: Double, bundle: Bundle = .main) -> String {
        MediaServerViewsCopy.resumeTitleString(seconds: seconds, bundle: bundle)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, item in
                guard let item else { return }
                if item.resumePositionSeconds > 1 {
                    showResumeDialog = true
                } else {
                    request = nil
                    start(item, resume: false)
                }
            }
            .confirmationDialog(Self.dialogTitle(itemName: request?.name),
                                isPresented: $showResumeDialog,
                                titleVisibility: .visible,
                                presenting: request) { item in
                Button(Self.resumeTitleKey(seconds: item.resumePositionSeconds)) {
                    start(item, resume: true)
                }
                Button(MediaServerViewsCopy.startFromBeginningKey) {
                    start(item, resume: false)
                }
                Button(MediaServerViewsCopy.cancelKey, role: .cancel) {}
            }
            .onChange(of: showResumeDialog) { _, shown in
                if !shown { request = nil }
            }
            .fullScreenCover(isPresented: $showPlayer) {
                MediaServerPlayerView()
            }
            .alert(MediaServerViewsCopy.playbackFailedKey,
                   isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button(MediaServerViewsCopy.okKey, role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private func start(_ item: MediaItem, resume: Bool) {
        guard let client else { return }
        Task { @MainActor in
            do {
                showPlayer = true
                try await MediaServerPlaybackCoordinator.shared.play(item, account: account, client: client, resume: resume)
            } catch {
                showPlayer = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct MediaServerPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var coordinator = MediaServerPlaybackCoordinator.shared

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: VideoPlayerService.shared.player)
                .ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding()
            .accessibilityLabel(MediaServerViewsCopy.closePlayerKey)
            .accessibilityIdentifier("mediaServerPlayerClose")
        }
        .onDisappear {
            Task { await MediaServerPlaybackCoordinator.shared.stop() }
        }
    }
}
