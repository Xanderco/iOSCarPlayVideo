import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Manage imported playlists (rename, reorder, export .m3u), toggle hidden channel groups,
/// and export/import portable JSON backups.
public struct PlaylistManageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playlistStore: PlaylistStore

    @State private var renamingPlaylist: IPTVPlaylist?
    @State private var renameDraft: String = ""
    @State private var showingBackupImporter: Bool = false
    @State private var pendingImportData: Data?
    @State private var showingImportModeDialog: Bool = false
    @State private var shareItem: ShareFileItem?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    public init(playlistStore: PlaylistStore = .shared) {
        self.playlistStore = playlistStore
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                List {
                    playlistsSection
                    channelGroupsSection
                    backupSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Manage Playlists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.dcAccent)
                        .accessibilityIdentifier("PlaylistManage_DoneButton")
                }

                if !playlistStore.playlists.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                            .foregroundStyle(Color.dcAccent)
                    }
                }
            }
            .alert(
                "Rename Playlist",
                isPresented: Binding(
                    get: { renamingPlaylist != nil },
                    set: { if !$0 { renamingPlaylist = nil } }
                ),
                presenting: renamingPlaylist
            ) { playlist in
                TextField("Playlist name", text: $renameDraft)
                Button("Save") {
                    playlistStore.renamePlaylist(id: playlist.id, title: renameDraft)
                    renamingPlaylist = nil
                }
                Button("Cancel", role: .cancel) {
                    renamingPlaylist = nil
                }
            } message: { _ in
                Text("Enter a custom name for this playlist.")
            }
            .fileImporter(
                isPresented: $showingBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleBackupFileSelection(result)
            }
            .confirmationDialog(
                "Import Playlist Backup",
                isPresented: $showingImportModeDialog,
                titleVisibility: .visible
            ) {
                Button("Merge with Current") {
                    applyPendingBackup(replaceExisting: false)
                }
                Button("Replace Current", role: .destructive) {
                    applyPendingBackup(replaceExisting: true)
                }
                Button("Cancel", role: .cancel) {
                    pendingImportData = nil
                }
            } message: {
                Text("Choose whether to merge this backup with your current playlists or replace them.")
            }
            .sheet(item: $shareItem) { item in
                ActivityShareSheet(activityItems: [item.url])
            }
            .alert(
                "Playlist Backup",
                isPresented: Binding(
                    get: { statusMessage != nil },
                    set: { if !$0 { statusMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { statusMessage = nil }
            } message: {
                Text(statusMessage ?? "")
            }
            .alert(
                "Action Failed",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var playlistsSection: some View {
        Section {
            if playlistStore.playlists.isEmpty {
                Text("No imported playlists yet. Add one from Media Sources.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dcTextSecondary)
                    .listRowBackground(Color.dcSurface)
            } else {
                ForEach(playlistStore.playlists) { playlist in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(playlist.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.dcTextPrimary)

                            Text(playlistSubtitle(for: playlist))
                                .font(.system(size: 12))
                                .foregroundStyle(Color.dcTextSecondary)
                        }

                        Spacer()

                        Button {
                            renameDraft = playlist.title
                            renamingPlaylist = playlist
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.dcAccent)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Rename playlist"))

                        Button {
                            exportM3U(playlist)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.dcAccent)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Export M3U"))
                    }
                    .listRowBackground(Color.dcSurface)
                }
                .onMove { offsets, destination in
                    playlistStore.movePlaylists(fromOffsets: offsets, toOffset: destination)
                }
                .onDelete { offsets in
                    let ids = offsets.map { playlistStore.playlists[$0].id }
                    ids.forEach { playlistStore.removePlaylist(id: $0) }
                }
            }
        } header: {
            Text("Playlists")
        } footer: {
            if playlistStore.playlists.count > 1 {
                Text("Tap Edit to drag and reorder playlists. Order applies to both phone and car lists.")
            }
        }
    }

    private var channelGroupsSection: some View {
        Section {
            let groups = playlistStore.availableGroups
            if groups.isEmpty {
                Text("No channel groups available.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dcTextSecondary)
                    .listRowBackground(Color.dcSurface)
            } else {
                ForEach(groups, id: \.self) { group in
                    let count = playlistStore.allChannels.filter { $0.groupTitle == group }.count
                    Toggle(isOn: Binding(
                        get: { !playlistStore.isGroupHidden(group) },
                        set: { visible in
                            playlistStore.setGroupHidden(group, hidden: !visible)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.isEmpty ? String(localized: "Other") : group)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.dcTextPrimary)

                            Text("\(count) channels")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.dcTextSecondary)
                        }
                    }
                    .tint(Color.dcAccent)
                    .listRowBackground(Color.dcSurface)
                }
            }
        } header: {
            HStack {
                Text("Channel Groups")
                Spacer()
                if !playlistStore.hiddenGroups.isEmpty {
                    Button("Show All") {
                        playlistStore.showAllGroups()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dcAccent)
                    .accessibilityIdentifier("PlaylistManage_ShowAllGroupsButton")
                }
            }
        } footer: {
            Text("Hide groups you don't want to see in Media Sources or on the car display.")
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                exportBackup()
            } label: {
                Label("Export Backup (JSON)", systemImage: "arrow.up.doc.fill")
                    .foregroundStyle(Color.dcAccent)
            }
            .accessibilityIdentifier("PlaylistManage_ExportBackupButton")
            .listRowBackground(Color.dcSurface)

            Button {
                showingBackupImporter = true
            } label: {
                Label("Import Backup (JSON)", systemImage: "arrow.down.doc.fill")
                    .foregroundStyle(Color.dcAccent)
            }
            .accessibilityIdentifier("PlaylistManage_ImportBackupButton")
            .listRowBackground(Color.dcSurface)
        } header: {
            Text("Backup & Restore")
        } footer: {
            Text("Save your playlists, favorites, and hidden groups locally without an account.")
        }
    }

    // MARK: - Actions

    private func playlistSubtitle(for playlist: IPTVPlaylist) -> LocalizedStringKey {
        if let host = playlist.url?.host, !host.isEmpty {
            return "\(playlist.channels.count) channels · \(host)"
        }
        return "\(playlist.channels.count) channels"
    }

    private func exportM3U(_ playlist: IPTVPlaylist) {
        let m3u = PlaylistBackupService.exportM3U(playlist: playlist)
        let baseName = PlaylistBackupService.sanitizedFilename(from: playlist.title)
        do {
            let url = try PlaylistBackupService.writeTemporaryFile(
                data: Data(m3u.utf8),
                filename: "\(baseName).m3u"
            )
            shareItem = ShareFileItem(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportBackup() {
        do {
            let data = try playlistStore.exportBackupData()
            let url = try PlaylistBackupService.writeTemporaryFile(
                data: data,
                filename: "DashCast-Playlists-Backup.json"
            )
            shareItem = ShareFileItem(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleBackupFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                // Validate early before prompting Merge vs Replace.
                _ = try PlaylistBackupService.decodeBackup(from: data)
                if playlistStore.playlists.isEmpty
                    && playlistStore.favoriteIDs.isEmpty
                    && playlistStore.hiddenGroups.isEmpty {
                    pendingImportData = data
                    applyPendingBackup(replaceExisting: false)
                } else {
                    pendingImportData = data
                    showingImportModeDialog = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func applyPendingBackup(replaceExisting: Bool) {
        guard let data = pendingImportData else { return }
        pendingImportData = nil
        do {
            let summary = try playlistStore.importBackupData(data, replaceExisting: replaceExisting)
            statusMessage = String(
                localized: "Restored \(summary.playlistsAdded + summary.playlistsUpdated) playlists and \(summary.favoritesAdded) new favorites."
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShareFileItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
