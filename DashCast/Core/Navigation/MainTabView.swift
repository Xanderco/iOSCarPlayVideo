import SwiftUI

public struct MiniPlayerBarState: Equatable {
    public let title: String
    public let subtitle: String?
    public let artworkURL: URL?
    public let isPlaying: Bool
    public let isLive: Bool
    public let isBuffering: Bool
    public let progress: Double?

    public static func shouldShow(
        currentChannel: ChannelModel?,
        selectedTab: AppState.TabItem
    ) -> Bool {
        currentChannel != nil && selectedTab != .cast
    }

    public static func make(
        channel: ChannelModel,
        isPlaying: Bool,
        isBuffering: Bool,
        currentTime: Double,
        duration: Double
    ) -> MiniPlayerBarState {
        let trimmedGroup = channel.groupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLive = !duration.isFinite || duration <= 0
        let progress: Double?
        if !isLive, currentTime.isFinite {
            progress = min(max(currentTime / duration, 0), 1)
        } else {
            progress = nil
        }

        return MiniPlayerBarState(
            title: channel.name,
            subtitle: trimmedGroup.isEmpty ? nil : trimmedGroup,
            artworkURL: channel.logoURL,
            isPlaying: isPlaying,
            isLive: isLive,
            isBuffering: isBuffering,
            progress: progress
        )
    }
}

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var playerService = VideoPlayerService.shared
    @AppStorage(PassengerSafetyNotice.acceptedKey) private var passengerNoticeAccepted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    private var shouldShowMiniPlayer: Bool {
        MiniPlayerBarState.shouldShow(
            currentChannel: playerService.currentChannel,
            selectedTab: appState.selectedTab
        )
    }

    public var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                // Native system tab bar: on iOS 26 it is rendered by the system in Liquid Glass
                // (translucency, morphing selection, minimise-on-scroll) at no CPU cost to us.
                TabView(selection: $appState.selectedTab) {
                    Tab(AppState.TabItem.cast.localizedTitle, systemImage: AppState.TabItem.cast.iconName, value: AppState.TabItem.cast) {
                        screen(.cast)
                    }
                    Tab(AppState.TabItem.drive.localizedTitle, systemImage: AppState.TabItem.drive.iconName, value: AppState.TabItem.drive) {
                        tabContentWithMiniPlayer(.drive)
                    }
                    Tab(AppState.TabItem.widgets.localizedTitle, systemImage: AppState.TabItem.widgets.iconName, value: AppState.TabItem.widgets) {
                        tabContentWithMiniPlayer(.widgets)
                    }
                    Tab(AppState.TabItem.sounds.localizedTitle, systemImage: AppState.TabItem.sounds.iconName, value: AppState.TabItem.sounds) {
                        tabContentWithMiniPlayer(.sounds)
                    }
                    Tab(AppState.TabItem.me.localizedTitle, systemImage: AppState.TabItem.me.iconName, value: AppState.TabItem.me) {
                        tabContentWithMiniPlayer(.me)
                    }
                }
                .tint(Color.dashYellow)
            } else {
                legacyTabs
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $appState.showPaywall) {
            LifetimePaywallView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { (!passengerNoticeAccepted && !PassengerSafetyNotice.shouldSkip) || ScreenshotLaunch.showOnboarding },
            set: { _ in }
        )) {
            // First-run walkthrough; includes the required passenger-only acknowledgement.
            WelcomeOnboardingView { passengerNoticeAccepted = true }
                .environmentObject(appState)
        }
    }

    @ViewBuilder
    private func tabContentWithMiniPlayer(_ item: AppState.TabItem) -> some View {
        screen(item)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let channel = playerService.currentChannel, shouldShowMiniPlayer {
                    miniPlayerBar(for: channel)
                        .padding(.bottom, DSSpacing.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(DSMotion.animation(DSMotion.standard, reduceMotion: reduceMotion), value: shouldShowMiniPlayer)
    }

    @ViewBuilder
    private func miniPlayerBar(for channel: ChannelModel) -> some View {
        let state = MiniPlayerBarState.make(
            channel: channel,
            isPlaying: playerService.isPlaying,
            isBuffering: playerService.isBuffering,
            currentTime: playerService.currentTime,
            duration: playerService.duration
        )

        MiniPlayerBar(
            title: state.title,
            subtitle: state.subtitle,
            artworkURL: state.artworkURL,
            isPlaying: state.isPlaying,
            isLive: state.isLive,
            isBuffering: state.isBuffering,
            progress: state.progress,
            onExpand: {
                withAnimation(DSMotion.animation(DSMotion.quick, reduceMotion: reduceMotion)) {
                    appState.selectedTab = .cast
                }
            },
            onPlayPause: {
                playerService.togglePlayPause()
            },
            onClose: {
                playerService.stop()
            }
        )
    }

    @ViewBuilder
    private func screen(_ item: AppState.TabItem) -> some View {
        switch item {
        case .cast: CastHomeView().accessibilityElement(children: .contain).accessibilityIdentifier("Screen_Cast")
        case .drive: DriveHomeView().accessibilityElement(children: .contain).accessibilityIdentifier("Screen_Drive")
        case .widgets: WidgetsHomeView().accessibilityElement(children: .contain).accessibilityIdentifier("Screen_Widgets")
        case .sounds: SoundsHomeView().accessibilityElement(children: .contain).accessibilityIdentifier("Screen_Sounds")
        case .me: MeHomeView().accessibilityElement(children: .contain).accessibilityIdentifier("Screen_Me")
        }
    }

    /// iOS 17 fallback: the previous floating capsule bar.
    private var legacyTabs: some View {
        ZStack(alignment: .bottom) {
            Color.dashBackground.ignoresSafeArea()
            ZStack {
                ForEach(AppState.TabItem.allCases) { item in
                    screen(item)
                        .opacity(appState.selectedTab == item ? 1 : 0)
                        .allowsHitTesting(appState.selectedTab == item)
                        .accessibilityHidden(appState.selectedTab != item)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: DSSpacing.sm) {
                if let channel = playerService.currentChannel, shouldShowMiniPlayer {
                    miniPlayerBar(for: channel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                LiquidCapsuleTabBar(selectedTab: $appState.selectedTab)
            }
            .animation(DSMotion.animation(DSMotion.standard, reduceMotion: reduceMotion), value: shouldShowMiniPlayer)
        }
    }
}
