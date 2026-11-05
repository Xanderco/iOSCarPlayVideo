import SwiftUI
import AVKit

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
                        Text("Connect a Jellyfin or Emby server to browse and play your own movies and shows.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.accounts) { account in
                        NavigationLink {
                            MediaLibrariesView(account: account)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "server.rack")
                                    .foregroundStyle(Color.dcAccent)
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
                        Label("Add Server", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("addMediaServerButton")
                } header: {
                    Text("Jellyfin & Emby")
                }

                Section {
                    Button {
                        showingQRScanner = true
                    } label: {
                        Label("Scan Playlist QR Code", systemImage: "qrcode.viewfinder")
                    }
                    .accessibilityIdentifier("scanPlaylistQRButton")
                } header: {
                    Text("Playlists")
                } footer: {
                    Text("Scan a QR code containing an M3U / M3U8 playlist link to add it to your channels.")
                }
            }
            .navigationTitle("Media Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                AddMediaServerView()
            }
            .sheet(isPresented: $showingQRScanner) {
                PlaylistQRImportView()
            }
        }
        .tint(Color.dcAccent)
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

    /// `kind` preselects Jellyfin or Emby when opened from Library → Add Source.
    public init(kind: MediaServerKind = .jellyfin) {
        _kind = State(initialValue: kind)
    }

    private var canSubmit: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !isConnecting
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    Picker("Type", selection: $kind) {
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
                Section("Account") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("mediaServerUsernameField")
                    SecureField("Password", text: $password)
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
                            if isConnecting { ProgressView() } else { Text("Connect").bold() }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("mediaServerConnectButton")
                } footer: {
                    Text("Your access token is stored securely in the iOS Keychain. Your password is never saved.")
                }
            }
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                Section("Continue Watching") {
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
                Section("Libraries") {
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
                Text("Nothing here yet").foregroundStyle(.secondary)
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
                    Color.dcSurfaceRaised
                    Image(systemName: item.isSeries ? "tv" : "film")
                        .font(.title)
                        .foregroundStyle(Color.dcTextTertiary)
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
                    .fill(Color.dcAccent)
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
                Color.dcSurfaceRaised
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .bottom) { MediaProgressBar(item: item) }

            VStack(alignment: .leading, spacing: 2) {
                if let label = item.episodeLabel {
                    Text(label).font(.caption2.weight(.bold)).foregroundStyle(Color.dcAccent)
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
            .confirmationDialog(request?.name ?? "Play",
                                isPresented: $showResumeDialog,
                                titleVisibility: .visible,
                                presenting: request) { item in
                Button("Resume from \(MediaTimeFormat.string(item.resumePositionSeconds))") {
                    start(item, resume: true)
                }
                Button("Start from Beginning") {
                    start(item, resume: false)
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: showResumeDialog) { _, shown in
                if !shown { request = nil }
            }
            .fullScreenCover(isPresented: $showPlayer) {
                MediaServerPlayerView()
            }
            .alert("Playback Failed",
                   isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
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
            .accessibilityLabel("Close player")
            .accessibilityIdentifier("mediaServerPlayerClose")
        }
        .onDisappear {
            Task { await MediaServerPlaybackCoordinator.shared.stop() }
        }
    }
}
