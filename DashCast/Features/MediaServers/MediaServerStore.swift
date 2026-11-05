import Foundation
import Combine
import AVFoundation

/// Saved Jellyfin / Emby logins. Account metadata goes to UserDefaults; the
/// access token goes ONLY to the Keychain via `MediaServerTokenStore`.
@MainActor
public final class MediaServerStore: ObservableObject {
    public static let shared = MediaServerStore()

    @Published public private(set) var accounts: [MediaServerAccount] = []

    private let defaults: UserDefaults
    private let tokenStore: MediaServerTokenStore
    private let session: URLSession
    private let accountsKey = "dashcast_media_server_accounts"
    private let deviceIdKey = "dashcast_media_server_device_id"

    public init(defaults: UserDefaults = .standard,
                tokenStore: MediaServerTokenStore = KeychainMediaServerTokenStore.shared,
                session: URLSession = .shared) {
        self.defaults = defaults
        self.tokenStore = tokenStore
        self.session = session
        if let data = defaults.data(forKey: accountsKey),
           let saved = try? JSONDecoder().decode([MediaServerAccount].self, from: data) {
            accounts = saved
        }
    }

    /// Stable per-install device id the server uses to group sessions.
    public var deviceId: String {
        if let existing = defaults.string(forKey: deviceIdKey) { return existing }
        let new = UUID().uuidString
        defaults.set(new, forKey: deviceIdKey)
        return new
    }

    /// Validates the address, signs in, stores the token in the Keychain and saves the account.
    @discardableResult
    public func signIn(kind: MediaServerKind,
                       serverAddress: String,
                       username: String,
                       password: String) async throws -> MediaServerAccount {
        guard let baseURL = MediaServerClient.normalizedServerURL(serverAddress, kind: kind) else {
            throw MediaServerError.invalidServerURL
        }
        let client = MediaServerClient(kind: kind, baseURL: baseURL, deviceId: deviceId, session: session)
        let info = try? await client.publicSystemInfo()
        let auth = try await client.authenticate(username: username, password: password)

        let account = MediaServerAccount(kind: kind,
                                         baseURL: baseURL,
                                         serverName: info?.serverName ?? baseURL.host ?? kind.displayName,
                                         serverId: auth.serverId ?? info?.id,
                                         username: auth.user.name ?? username,
                                         userId: auth.user.id,
                                         deviceId: deviceId)
        // Replace an existing login for the same server + user.
        if let old = accounts.first(where: { $0.baseURL == account.baseURL && $0.userId == account.userId }) {
            tokenStore.removeToken(for: old.id)
            accounts.removeAll { $0.id == old.id }
        }
        tokenStore.setToken(auth.accessToken, for: account.id)
        accounts.append(account)
        persist()
        return account
    }

    public func client(for account: MediaServerAccount) -> MediaServerClient {
        MediaServerClient(account: account, accessToken: tokenStore.token(for: account.id), session: session)
    }

    public func hasToken(for account: MediaServerAccount) -> Bool {
        tokenStore.token(for: account.id) != nil
    }

    public func remove(_ account: MediaServerAccount) {
        let client = client(for: account)
        Task { await client.logout() }
        tokenStore.removeToken(for: account.id)
        accounts.removeAll { $0.id == account.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: accountsKey)
        }
    }
}

/// Plays server items through the shared `VideoPlayerService`, resumes from the
/// saved position and reports progress back to the server.
@MainActor
public final class MediaServerPlaybackCoordinator: ObservableObject {
    public static let shared = MediaServerPlaybackCoordinator()

    @Published public private(set) var nowPlaying: MediaItem?

    private var client: MediaServerClient?
    private var report: MediaServerClient.PlaybackReport?
    private var channelId: String?
    private var reportingTask: Task<Void, Never>?
    private let player: VideoPlayerService

    public init(player: VideoPlayerService? = nil) {
        // Resolved here, not as a default argument (those run nonisolated).
        self.player = player ?? .shared
    }

    static func channelId(for item: MediaItem, account: MediaServerAccount) -> String {
        "mediaserver-\(account.id.uuidString)-\(item.id)"
    }

    /// Builds the channel model handed to `VideoPlayerService`.
    static func channel(for item: MediaItem,
                        account: MediaServerAccount,
                        client: MediaServerClient,
                        playSessionId: String) throws -> ChannelModel {
        let title: String
        if let series = item.seriesName, let label = item.episodeLabel {
            title = "\(series) · \(label) · \(item.name)"
        } else {
            title = item.name
        }
        return ChannelModel(id: channelId(for: item, account: account),
                            name: title,
                            streamURL: try client.streamURL(for: item, playSessionId: playSessionId),
                            groupTitle: account.serverName,
                            logoURL: client.imageURL(for: item))
    }

    public func play(_ item: MediaItem, account: MediaServerAccount, client: MediaServerClient, resume: Bool = true) async throws {
        await stopReporting()

        // Refresh to get the latest resume position and media sources.
        let fresh = (try? await client.item(id: item.id)) ?? item
        let playSessionId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let channel = try Self.channel(for: fresh, account: account, client: client, playSessionId: playSessionId)
        let method: String
        if case .directPlay = MediaStreamMode.preferred(for: fresh) { method = "DirectPlay" } else { method = "Transcode" }

        player.load(channel: channel)

        let resumeAt = resume ? fresh.resumePositionSeconds : 0
        if resumeAt > 1 {
            await seekWhenReady(to: resumeAt)
        }

        self.client = client
        self.channelId = channel.id
        self.nowPlaying = fresh
        let report = MediaServerClient.PlaybackReport(itemId: fresh.id,
                                                      mediaSourceId: fresh.mediaSources?.first?.id ?? fresh.id,
                                                      playSessionId: playSessionId,
                                                      positionTicks: MediaTicks.ticks(fromSeconds: resumeAt),
                                                      isPaused: false,
                                                      playMethod: method)
        self.report = report
        try? await client.reportPlayback(.start, report: report)
        startReportingLoop()
    }

    /// Call when the player UI is dismissed.
    public func stop() async {
        player.pause()
        await stopReporting()
    }

    private func seekWhenReady(to seconds: Double) async {
        for _ in 0..<60 { // up to ~15 s
            if let item = player.player.currentItem {
                if item.status == .readyToPlay { break }
                if item.status == .failed { return }
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        player.seek(to: seconds)
    }

    private func currentReport() -> MediaServerClient.PlaybackReport? {
        guard var report else { return nil }
        // Only sample the shared player while it is still playing our item.
        guard player.currentChannel?.id == channelId else { return report }
        let position = player.player.currentTime().seconds
        if position.isFinite, position > 0 { report.positionTicks = MediaTicks.ticks(fromSeconds: position) }
        report.isPaused = !player.isPlaying
        self.report = report
        return report
    }

    private func startReportingLoop() {
        reportingTask?.cancel()
        reportingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled, let self else { return }
                // Another source took over the shared player: stop reporting.
                if self.player.currentChannel?.id != self.channelId {
                    await self.stopReporting()
                    return
                }
                if let client = self.client, let report = self.currentReport() {
                    try? await client.reportPlayback(.progress, report: report)
                }
            }
        }
    }

    private func stopReporting() async {
        reportingTask?.cancel()
        reportingTask = nil
        if let client, let report = currentReport() {
            try? await client.reportPlayback(.stopped, report: report)
        }
        client = nil
        report = nil
        channelId = nil
        nowPlaying = nil
    }
}
