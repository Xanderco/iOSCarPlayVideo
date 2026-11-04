import SwiftUI
import AVFoundation

public struct OfflineMediaLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var cacheService = DeadzoneCacheService.shared
    @StateObject private var preloader = MediaPreloaderService.shared
    @StateObject private var playerService = VideoPlayerService.shared

    @State private var showingSettingsSheet: Bool = false
    @State private var showingClearConfirm: Bool = false
    @State private var customURLInput: String = ""
    @State private var showingAddPreloadAlert: Bool = false
    @State private var selectedFilter: String = "All"

    private let filterTabs = ["All", "Pinned", "Preloading"]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Storage Usage & LiquidCapsule Gauge Card
                        storageGaugeCard

                        // 2. Deadzone Playback Mode Quick Toggle
                        deadzoneModeCard

                        // 3. Preloader Quick Actions Section
                        preloaderControlsSection

                        // 4. Filter Capsule Pills
                        filterCapsulesSection

                        // 5. Active Preloading Tasks (if any)
                        if !preloader.activeDownloads.isEmpty {
                            activeDownloadsSection
                        }

                        // 6. Cached Streams Collection
                        cachedStreamsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Offline Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(Color.dashYellow)
                        .frame(minWidth: 48, minHeight: 48)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingSettingsSheet = true
                        } label: {
                            Label("Storage Quota Settings", systemImage: "slider.horizontal.3")
                        }

                        Button(role: .destructive) {
                            showingClearConfirm = true
                        } label: {
                            Label("Clear Unpinned Cache", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.dashYellow)
                            .frame(minWidth: 48, minHeight: 48)
                    }
                }
            }
            .sheet(isPresented: $showingSettingsSheet) {
                OfflineCacheSettingsView()
            }
            .alert("Clear Unpinned Cache?", isPresented: $showingClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    cacheService.clearAllUnpinned()
                }
            } message: {
                Text("This will remove all downloaded streams except your pinned favorites to free up storage space.")
            }
        }
    }

    // MARK: - 1. Storage Gauge Card (LiquidCapsule Aesthetic)
    private var storageGaugeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.dashYellow)
                    Text("OFFLINE STORAGE CACHE")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color.dashTextPrimary)
                }

                Spacer()

                // Pinned pill count
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                    Text("\(cacheService.metrics.pinnedItemCount) PINNED")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.dashGold.opacity(0.15))
                .foregroundStyle(Color.dashGold)
                .clipShape(Capsule())
            }

            // Dual-tone LiquidCapsule Storage Bar
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let usedRatio = CGFloat(cacheService.metrics.usagePercentage)
                let usedWidth = max(4, totalWidth * usedRatio)

                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.dashSurfaceHighlight)
                        .frame(height: 12)

                    // Active Cache Gradient Bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.dashYellow, Color.dashGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: usedWidth, height: 12)
                        .shadow(color: Color.dashYellow.opacity(0.5), radius: 6, x: 0, y: 0)
                }
            }
            .frame(height: 12)

            // Usage Numbers Row
            HStack {
                Text(cacheService.metrics.formattedUsage)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.dashYellow)

                Spacer()

                Text("\(cacheService.metrics.itemCount) clips cached")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dashTextSecondary)
            }
        }
        .padding(18)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    // MARK: - 2. Deadzone Mode Quick Card
    private var deadzoneModeCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(cacheService.isDeadzoneActive ? Color.dashYellow.opacity(0.2) : Color.dashSurfaceHighlight)
                    .frame(width: 44, height: 44)

                Image(systemName: cacheService.isDeadzoneActive ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(cacheService.isDeadzoneActive ? Color.dashYellow : Color.dashTextMuted)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Deadzone Fallback Mode")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dashTextPrimary)
                Text(cacheService.isDeadzoneActive ? "Forcing local cached streams for tunnels & blindspots" : "Auto-switch to cache if connection drops")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextSecondary)
            }

            Spacer()

            Toggle("", isOn: $cacheService.isDeadzoneActive)
                .labelsHidden()
                .tint(Color.dashYellow)
        }
        .padding(16)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cacheService.isDeadzoneActive ? Color.dashYellow.opacity(0.4) : Color.dashBorder, lineWidth: 1)
        )
    }

    // MARK: - 3. Preloader Quick Actions
    private var preloaderControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRELOAD CONTROLS")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color.dashTextMuted)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                // Button 1: Preload Bundled Clips (Zero internet requirement)
                Button {
                    preloader.preloadBundledClips()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Preload 1080p Bundle")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.dashYellow)
                    .foregroundStyle(Color.dashBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // Button 2: Storage Settings Shortcut
                Button {
                    showingSettingsSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                        Text("Quota")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(width: 90, height: 48)
                    .background(Color.dashSurfaceHighlight)
                    .foregroundStyle(Color.dashTextPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.dashBorder, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - 4. Filter Capsules
    private var filterCapsulesSection: some View {
        HStack(spacing: 8) {
            ForEach(filterTabs, id: \.self) { tab in
                let isSelected = selectedFilter == tab
                Button {
                    selectedFilter = tab
                } label: {
                    Text(tab)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.dashYellow : Color.dashSurface)
                        .foregroundStyle(isSelected ? Color.dashBackground : Color.dashTextSecondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(isSelected ? Color.clear : Color.dashBorder, lineWidth: 1)
                        )
                }
                .frame(minHeight: 48)
            }
            Spacer()
        }
    }

    // MARK: - 5. Active Preloading Section
    private var activeDownloadsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DOWNLOADING IN BACKGROUND")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.dashGold)
                Spacer()
                ProgressView()
                    .tint(Color.dashGold)
            }
            .padding(.horizontal, 4)

            ForEach(Array(preloader.activeDownloads.keys), id: \.self) { sourceStr in
                if let progress = preloader.activeDownloads[sourceStr] {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(sourceStr)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.dashTextPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.dashGold)
                        }

                        ProgressView(value: progress, total: 1.0)
                            .tint(Color.dashGold)
                            .background(Color.dashSurfaceHighlight)
                    }
                    .padding(12)
                    .background(Color.dashSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    // MARK: - 6. Cached Streams Collection
    private var filteredItems: [DeadzoneCacheItem] {
        switch selectedFilter {
        case "Pinned":
            return cacheService.cachedItems.filter { $0.isPinned && $0.isComplete }
        case "Preloading":
            return cacheService.cachedItems.filter { !$0.isComplete }
        default:
            return cacheService.cachedItems.filter { $0.isComplete }
        }
    }

    private var cachedStreamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CACHED MEDIA LIBRARY")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.dashTextMuted)
                Spacer()
                Text("\(filteredItems.count) items")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.dashTextSecondary)
            }
            .padding(.horizontal, 4)

            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.dashTextMuted)
                    Text("No Cached Media Yet")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)
                    Text("Preload automotive video clips or stream channels to enable playback in cellular deadzones and tunnels.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button {
                        preloader.preloadBundledClips()
                    } label: {
                        Text("Preload 1080p Clips Now")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(Color.dashYellow.opacity(0.15))
                            .foregroundStyle(Color.dashYellow)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.dashSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.dashBorder, lineWidth: 1)
                )
            } else {
                ForEach(filteredItems) { item in
                    cachedItemRow(item: item)
                }
            }
        }
    }

    private func cachedItemRow(item: DeadzoneCacheItem) -> some View {
        HStack(spacing: 14) {
            // Play Button Thumbnail Icon
            Button {
                let channel = item.toChannelModel(cacheDirectory: cacheService.storageEngine.cacheDirectory)
                playerService.load(channel: channel)
                playerService.play()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.dashSurfaceHighlight)
                        .frame(width: 50, height: 50)

                    Image(systemName: "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.dashYellow)
                }
            }
            .frame(minWidth: 48, minHeight: 48)

            // Info Column
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.channelName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)
                        .lineLimit(1)

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.dashGold)
                    }
                }

                HStack(spacing: 8) {
                    Text(item.groupTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.dashTextMuted)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dashTextMuted)

                    Text(item.formattedSize)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.dashYellow)
                }
            }

            Spacer()

            // Pin / Unpin Button (48x48pt hit target)
            Button {
                cacheService.togglePin(id: item.id)
            } label: {
                Image(systemName: item.isPinned ? "pin.slash.fill" : "pin.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(item.isPinned ? Color.dashGold : Color.dashTextMuted)
                    .frame(width: 48, height: 48)
            }

            // Delete Button (48x48pt hit target)
            Button {
                cacheService.deleteItem(id: item.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dashRed.opacity(0.8))
                    .frame(width: 48, height: 48)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(item.isPinned ? Color.dashGold.opacity(0.3) : Color.dashBorder, lineWidth: 1)
        )
    }
}
