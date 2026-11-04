import SwiftUI

public struct OfflineCacheSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cacheService = DeadzoneCacheService.shared
    @State private var preferences: UserPreferences = PersistenceController.shared.loadUserPreferences()
    @State private var showingClearAlert: Bool = false
    @State private var clearedBytesNotice: String? = nil

    private let quotaOptions: [Int] = [2, 5, 10, 20, 50]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Quota Picker Section
                        storageQuotaSection

                        // 2. Automated Download Behaviors
                        automationSection

                        // 3. Cache Storage Management & Purge
                        cachePurgeSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Storage & Cache")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(Color.dashYellow)
                        .frame(minWidth: 48, minHeight: 48)
                    }
                }
            }
            .alert("Purge Entire Offline Cache?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Purge All", role: .destructive) {
                    let oldSize = cacheService.metrics.currentSizeBytes
                    cacheService.clearAllUnpinned()
                    clearedBytesNotice = "Freed storage cache."
                }
            } message: {
                Text("All unpinned offline media files will be deleted from your iPhone storage.")
            }
        }
    }

    // MARK: - 1. Storage Quota Section
    private var storageQuotaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MAXIMUM STORAGE QUOTA")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.dashTextMuted)
                Spacer()
                Text("\(preferences.offlineCacheMaxGigabytes) GB CAP")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.dashYellow)
            }

            Text("Set the maximum local storage DashCast can use for caching deadzone video streams and clips.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dashTextSecondary)

            // Segmented Quota Buttons (48pt touch height)
            HStack(spacing: 8) {
                ForEach(quotaOptions, id: \.self) { gb in
                    let isSelected = preferences.offlineCacheMaxGigabytes == gb
                    Button {
                        preferences.offlineCacheMaxGigabytes = gb
                        savePreferences()
                        cacheService.setMaxStorageGigabytes(gb)
                    } label: {
                        Text("\(gb) GB")
                            .font(.system(size: 13, weight: isSelected ? .heavy : .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(isSelected ? Color.dashYellow : Color.dashSurfaceHighlight)
                            .foregroundStyle(isSelected ? Color.dashBackground : Color.dashTextPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? Color.clear : Color.dashBorder, lineWidth: 1)
                            )
                    }
                }
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

    // MARK: - 2. Automation Section
    private var automationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PRELOAD PREFERENCES")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color.dashTextMuted)

            // Toggle 1: Auto-preload on Wi-Fi
            toggleRow(
                icon: "wifi",
                title: "Preload on Wi-Fi",
                subtitle: "Automatically cache top channels when connected to home Wi-Fi",
                isOn: Binding(
                    get: { preferences.autoPreloadFavoritesOnWiFi },
                    set: { preferences.autoPreloadFavoritesOnWiFi = $0; savePreferences() }
                )
            )

            Divider().background(Color.dashBorder.opacity(0.5))

            // Toggle 2: Cellular Preload
            toggleRow(
                icon: "antenna.radiowaves.left.and.right",
                title: "Allow Cellular Downloads",
                subtitle: "Permit background stream preloading using mobile carrier data",
                isOn: Binding(
                    get: { preferences.allowCellularPreloading },
                    set: { preferences.allowCellularPreloading = $0; savePreferences() }
                )
            )

            Divider().background(Color.dashBorder.opacity(0.5))

            // Toggle 3: Auto-Eviction
            toggleRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Smart LRU Eviction",
                subtitle: "Evict oldest unpinned streams first when storage limit is reached",
                isOn: Binding(
                    get: { preferences.evictOldestWhenFull },
                    set: { preferences.evictOldestWhenFull = $0; savePreferences() }
                )
            )
        }
        .padding(18)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    // MARK: - 3. Cache Purge Section
    private var cachePurgeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CACHE MANAGEMENT")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color.dashTextMuted)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Disk Footprint")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dashTextPrimary)
                    Text(cacheService.metrics.formattedUsage)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.dashYellow)
                }
                Spacer()

                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    Text("Purge Cache")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(Color.dashRed.opacity(0.15))
                        .foregroundStyle(Color.dashRed)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if let notice = clearedBytesNotice {
                Text(notice)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dashGreen)
                    .padding(.top, 4)
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

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.dashSurfaceHighlight)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dashYellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dashTextPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextSecondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.dashYellow)
        }
    }

    private func savePreferences() {
        PersistenceController.shared.saveUserPreferences(preferences)
    }
}
