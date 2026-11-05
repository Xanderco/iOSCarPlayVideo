import SwiftUI

/// One place to add any kind of source: a playlist link, a playlist file,
/// a QR code, or a Jellyfin / Emby server.
public struct AddSourceSheet: View {
    enum Method: String, CaseIterable, Identifiable {
        case link = "Link"
        case file = "File"
        case qr = "QR Code"
        case server = "Server"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playlistStore = PlaylistStore.shared

    @State private var method: Method = .link
    @State private var link = ""
    @State private var name = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showingFileImporter = false
    @State private var showingQRScanner = false
    @State private var showingServers = false
    @FocusState private var linkFocused: Bool

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xl) {
                    Picker("Source type", selection: $method) {
                        ForEach(Method.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch method {
                    case .link: linkForm
                    case .file: fileForm
                    case .qr: qrForm
                    case .server: serverForm
                    }
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
            .sheet(isPresented: $showingServers) { MediaServersHomeView() }
        }
        .tint(Color.dcAccent)
        .presentationDetents([.medium, .large])
    }

    // MARK: - Forms

    private var linkForm: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            explainer("Paste the address of an M3U / M3U8 playlist, or of a single HLS stream.")
            field("Playlist link", text: $link, prompt: "https://…/playlist.m3u", keyboard: .URL)
                .focused($linkFocused)
                .accessibilityIdentifier("AddSource_Link")
            field("Name (optional)", text: $name, prompt: "e.g. Family TV", keyboard: .default)
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(DSTypography.footnote)
                    .foregroundStyle(Color.dcWarning)
            }
            PrimaryButton("Add", systemImage: "plus", isLoading: isImporting) {
                Task { await importLink() }
            }
            .disabled(link.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("AddSource_Submit")
        }
        .onAppear { linkFocused = link.isEmpty }
    }

    private var fileForm: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            explainer("Pick an .m3u or .m3u8 file from Files, iCloud Drive or a USB drive.")
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(DSTypography.footnote)
                    .foregroundStyle(Color.dcWarning)
            }
            PrimaryButton("Choose a File", systemImage: "folder") { showingFileImporter = true }
        }
    }

    private var qrForm: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            explainer("Point the camera at a QR code that contains a playlist link — handy for copying a playlist from a computer screen.")
            PrimaryButton("Scan a QR Code", systemImage: "qrcode.viewfinder") { showingQRScanner = true }
        }
    }

    private var serverForm: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            explainer("Sign in to your own Jellyfin or Emby server to browse movies and shows. Your password stays in the iPhone Keychain.")
            PrimaryButton("Connect a Server", systemImage: "server.rack") { showingServers = true }
        }
    }

    private func explainer(_ text: String) -> some View {
        Text(text)
            .font(DSTypography.callout)
            .foregroundStyle(Color.dcTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
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
