import SwiftUI

public struct StorageQuotaManagementView: View {
    @ObservedObject private var cacheService = OfflineStreamCacheService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingClearConfirmation: Bool = false
    @State private var showingClearAllConfirmation: Bool = false

    private let quotaOptions: [Int] = [2, 5, 10, 25, 50]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Top Storage Gauge Card
                        storageGaugeCard

                        // Rolling Highway Buffer Control Card
                        highwayBufferCard

                        // Storage Quota Selector Card
                        quotaSelectorCard

                        // 1-Tap Cache Clear Actions
                        clearActionsCard

                        // Cached Streams List
                        cachedStreamsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Storage & Highway Cache")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.dashYellow)
                }
            }
            .alert("Clear Unpinned Cache?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    cacheService.clearUnpinnedCache()
                }
            } message: {
                let unpinnedBytes = cacheService.items.filter { !$0.isPinned }.reduce(0) { $0 + $1.fileSizeBytes }
                let mb = Double(unpinnedBytes) / (1024 * 1024)
                Text("This will remove \(String(format: "%.1f", mb)) MB of cached streams. Pinned favorites will be kept.")
            }
            .alert("Clear Entire Cache?", isPresented: $showingClearAllConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    cacheService.clearAllCache()
                }
            } message: {
                Text("This will delete all offline cached video streams including pinned favorites.")
            }
        }
    }

    // MARK: - Top Storage Gauge

    private var storageGaugeCard: some View {
        let metrics = cacheService.metrics

        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STREAM CACHE STORAGE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.dashTextSecondary)

                    Text(metrics.formattedUsage)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.dashTextPrimary)
                }

                Spacer()

                // Status Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(metrics.highwayBufferActive ? Color.dashYellow : Color.dashTextMuted)
                        .frame(width: 8, height: 8)

                    Text(metrics.highwayBufferActive ? "HIGHWAY READY" : "STANDARD")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(metrics.highwayBufferActive ? Color.dashYellow : Color.dashTextMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.dashYellow.opacity(metrics.highwayBufferActive ? 0.15 : 0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(metrics.highwayBufferActive ? Color.dashYellow.opacity(0.4) : Color.dashBorder, lineWidth: 1)
                )
            }

            // Neon Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: "#14171E"))
                        .frame(height: 14)

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.dashYellow, Color(hex: "#FFB800")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(metrics.usagePercentage)), height: 14)
                        .shadow(color: Color.dashYellow.opacity(0.4), radius: 6, y: 0)
                }
            }
            .frame(height: 14)

            // Sub-metrics row
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 11))
                    Text("\(metrics.itemCount) streams")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.dashTextSecondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                    Text("\(metrics.pinnedItemCount) pinned")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.dashTextSecondary)

                Spacer()

                Text("\(Int(metrics.usagePercentage * 100))% used")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dashYellow)
            }
        }
        .padding(18)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))
    }

    // MARK: - Rolling Highway Buffer Card

    private var highwayBufferCard: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $cacheService.isHighwayBufferEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "road.lanes.curved.right")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.dashYellow)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rolling 60s Highway Buffer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.dashTextPrimary)

                        Text("Buffers 60s forward to survive cellular dead zones, mountain roads, and tunnels.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dashTextSecondary)
                    }
                }
            }
            .tint(Color.dashYellow)
        }
        .padding(16)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))
    }

    // MARK: - Quota Selector Card

    private var quotaSelectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dashYellow)

                Text("Cache Quota Limit")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.dashTextPrimary)

                Spacer()

                Text("\(cacheService.quotaSizeBytes / (1024 * 1024 * 1024)) GB")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.dashYellow)
            }

            // Quota buttons row
            HStack(spacing: 8) {
                ForEach(quotaOptions, id: \.self) { gb in
                    let isSelected = (cacheService.quotaSizeBytes / (1024 * 1024 * 1024)) == Int64(gb)

                    Button {
                        cacheService.setMaxQuotaGigabytes(gb)
                    } label: {
                        Text("\(gb) GB")
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.black : Color.dashTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.dashYellow : Color(hex: "#161922"))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isSelected ? Color.dashYellow : Color.dashBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))
    }

    // MARK: - 1-Tap Cache Clear Actions

    private var clearActionsCard: some View {
        VStack(spacing: 10) {
            Button {
                showingClearConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                    Text("1-Tap Clear Unpinned Cache")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    let unpinnedCount = cacheService.items.filter { !$0.isPinned }.count
                    Text("(\(unpinnedCount) items)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                }
                .foregroundStyle(Color.dashYellow)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.dashYellow.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.dashYellow.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(cacheService.items.filter { !$0.isPinned }.isEmpty)
            .opacity(cacheService.items.filter { !$0.isPinned }.isEmpty ? 0.4 : 1.0)
        }
    }

    // MARK: - Cached Streams Section

    private var cachedStreamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CACHED VIDEO STREAMS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.dashTextSecondary)

                Spacer()

                if !cacheService.items.isEmpty {
                    Button("Clear All") {
                        showingClearAllConfirmation = true
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.8))
                }
            }

            if cacheService.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.dashTextMuted)
                    Text("No streams cached yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.dashTextSecondary)
                    Text("Favorite and live streams will automatically preload segmented chunks for deadzone resilience.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.dashSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))
            } else {
                VStack(spacing: 1) {
                    ForEach(cacheService.items) { item in
                        streamRow(item: item)
                        if item.id != cacheService.items.last?.id {
                            Divider().background(Color.dashBorder.opacity(0.5))
                        }
                    }
                }
                .background(Color.dashSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))
            }
        }
    }

    private func streamRow(item: CachedStreamItem) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "#1A1D26"))
                    .frame(width: 36, height: 36)
                Image(systemName: item.contentType == .hls ? "play.tv.fill" : "video.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dashYellow)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dashTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(String(format: "%.1f MB", Double(item.fileSizeBytes) / (1024 * 1024)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.dashTextSecondary)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dashTextMuted)

                    Text("\(item.segmentCount) chunks")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dashTextMuted)
                }
            }

            Spacer()

            // Pin Button
            Button {
                cacheService.togglePin(id: item.id)
            } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 14))
                    .foregroundStyle(item.isPinned ? Color.dashYellow : Color.dashTextMuted)
                    .padding(8)
            }
            .buttonStyle(.plain)

            // Delete Button
            Button {
                cacheService.deleteItem(id: item.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.red.opacity(0.7))
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
