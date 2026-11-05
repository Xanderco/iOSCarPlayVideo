import SwiftUI

/// One place to add any kind of source: a playlist link, a playlist file,
/// a QR code, or a Jellyfin / Emby server.
public struct AddSourceSheet: View {
    enum Method: String, CaseIterable, Identifiable {
        case link, file, qr, jellyfin, emby
        var id: String { rawValue }

        var title: String {
            switch self {
            case .link: return "Playlist Link"
            case .file: return "Playlist File"
            case .qr: return "Scan a QR Code"
            case .jellyfin: return "Jellyfin Server"
            case .emby: return "Emby Server"
            }
        }

        var detail: String {
            switch self {
            case .link: return "Paste an M3U / M3U8 address or a single HLS stream."
            case .file: return "Pick an .m3u or .m3u8 file from Files or iCloud Drive."
            case .qr: return "Point the camera at a QR code that contains a playlist link."
            case .jellyfin: return "Sign in to your own Jellyfin server for movies and shows."
            case .emby: return "Sign in to your own Emby server for movies and shows."
            }
        }

        var systemImage: String {
            switch self {
            case .link: return "link"
            case .file: return "doc.badge.plus"
            case .qr: return "qrcode.viewfinder"
            case .jellyfin: return "server.rack"
            case .emby: return "externaldrive.connected.to.line.below"
            }
        }

        var tint: Color {
            switch self {
            case .link, .file: return .dcAccent
            case .qr: return .dcInfo
            case .jellyfin, .emby: return .dcWarning
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playlistStore = PlaylistStore.shared

    @State private var showingLinkForm = false
    @State private var link = ""
    @State private var name = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showingFileImporter = false
    @State private var showingQRScanner = false
    @State private var serverKind: MediaServerKind?
    @FocusState private var linkFocused: Bool

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    if let errorMessage, !showingLinkForm {
                        errorLabel(errorMessage)
                    }
                    ForEach(Method.allCases) { method in
                        optionRow(method)
                    }
                    Text("Sources stay on this iPhone. Server passwords are kept in the Keychain.")
                        .font(DSTypography.footnote)
                        .foregroundStyle(Color.dcTextTertiary)
                        .padding(.top, DSSpacing.sm)
                }
                .padding(DSSpacing.screenGutter)
            }
            .background(Color.dcBackgroundElevated.ignoresSafeArea())
            .navigationTitle("Add Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showingLinkForm) { linkForm }
            .fileImporter(isPresented: $showingFileImporter,
                          allowedContentTypes: PlaylistStore.playlistContentTypes,
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        try playlistStore.importPlaylist(fileURL: url)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showingQRScanner) { PlaylistQRImportView() }
            .sheet(item: $serverKind) { kind in AddMediaServerView(kind: kind) }
        }
        .tint(Color.dcAccent)
    }

    // MARK: - Options

    private func optionRow(_ method: Method) -> some View {
        Button {
            errorMessage = nil
            switch method {
            case .link: showingLinkForm = true
            case .file: showingFileImporter = true
            case .qr: showingQRScanner = true
            case .jellyfin: serverKind = .jellyfin
            case .emby: serverKind = .emby
            }
        } label: {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: method.systemImage)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(method.tint)
                    .frame(width: 44, height: 44)
                    .background(method.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(method.title)
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)
                    Text(method.detail)
                        .font(DSTypography.footnote)
                        .foregroundStyle(Color.dcTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DSSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dcTextTertiary)
                    .accessibilityHidden(true)
            }
            .dsCard(padding: DSSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("AddSource_\(method.rawValue)")
    }

    // MARK: - Link form

    private var linkForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(Method.link.detail)
                    .font(DSTypography.callout)
                    .foregroundStyle(Color.dcTextSecondary)
                field("Playlist link", text: $link, prompt: "https://…/playlist.m3u", keyboard: .URL)
                    .focused($linkFocused)
                    .accessibilityIdentifier("AddSource_Link")
                field("Name (optional)", text: $name, prompt: "e.g. Family TV", keyboard: .default)
                if let errorMessage {
                    errorLabel(errorMessage)
                }
                PrimaryButton("Add", systemImage: "plus", isLoading: isImporting) {
                    Task { await importLink() }
                }
                .disabled(link.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("AddSource_Submit")
            }
            .padding(DSSpacing.screenGutter)
        }
        .background(Color.dcBackgroundElevated.ignoresSafeArea())
        .navigationTitle(Method.link.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { linkFocused = link.isEmpty }
    }

    private func errorLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(DSTypography.footnote)
            .foregroundStyle(Color.dcWarning)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(label)
                .font(DSTypography.footnote.weight(.semibold))
                .foregroundStyle(Color.dcTextSecondary)
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(DSTypography.body)
                .padding(.horizontal, DSSpacing.md)
                .frame(minHeight: DSLayout.minTapTarget)
                .background(Color.dcSurfaceRaised, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                .accessibilityLabel(Text(label))
        }
    }

    // MARK: - Import

    private func importLink() async {
        let input = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        isImporting = true
        defer { isImporting = false }
        do {
            // A bare HLS media playlist is one stream, not a channel list.
            if let url = URL(string: input), url.pathExtension.lowercased() == "m3u8",
               let data = try? await URLSession.shared.data(from: url).0,
               let text = IPTVParser.decode(data), text.contains("#EXT-X-") {
                let streamName = title.isEmpty ? url.deletingPathExtension().lastPathComponent : title
                let m3u = "#EXTM3U\n#EXTINF:-1 group-title=\"Streams\",\(streamName)\n\(url.absoluteString)\n"
                try playlistStore.addPlaylist(data: Data(m3u.utf8), sourceURL: nil, title: streamName)
                let channel = ChannelModel(name: streamName, streamURL: url, groupTitle: "Streams")
                PlayerPresentation.shared.play(channel, expand: false)
            } else {
                try await playlistStore.importPlaylist(from: input, title: title.isEmpty ? nil : title)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
