import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class LocalVideoManager: ObservableObject {
    public static let shared = LocalVideoManager()

    nonisolated public static let supportedVideoContentTypes: [UTType] = [
        .movie,
        .video,
        .mpeg4Movie,
        .quickTimeMovie,
        .avi
    ]

    nonisolated private static let supportedVideoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi"
    ]

    nonisolated public static func isSupportedVideoURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        if supportedVideoExtensions.contains(ext) {
            return true
        }
        if let type = UTType(filenameExtension: ext) {
            return type.conforms(to: .movie) || type.conforms(to: .video)
        }
        return false
    }

    public enum ImportError: LocalizedError, Equatable {
        case noVideoData
        case unsupportedFileType
        case copyFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noVideoData:
                return "The selected item has no video data. If it is stored in iCloud, open it in Photos once to download it and try again."
            case .unsupportedFileType:
                return "That file isn't a supported video format."
            case .copyFailed(let reason):
                return "Couldn't save the video: \(reason)"
            }
        }
    }

    @Published public private(set) var localVideos: [ChannelModel] = []
    @Published public private(set) var isImporting: Bool = false

    static let defaultsKey = "dashcast_local_imported_videos"
    private let videosDirectory: URL
    private let defaults: UserDefaults

    public init(videosDirectory: URL? = nil, defaults: UserDefaults = .standard) {
        self.videosDirectory = videosDirectory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.defaults = defaults
        try? FileManager.default.createDirectory(at: self.videosDirectory, withIntermediateDirectories: true)
        loadSavedLocalVideos()
    }

    /// Imports a video picked with PhotosPicker into the app's Documents folder.
    /// Returns the new channel so the caller can start playing it.
    @discardableResult
    public func importVideo(from item: PhotosPickerItem) async throws -> ChannelModel {
        isImporting = true
        defer { isImporting = false }

        guard let movie = try await item.loadTransferable(type: MovieFileTransferable.self) else {
            throw ImportError.noVideoData
        }
        return try importFile(at: movie.url, originalName: movie.originalName)
    }

    /// Imports a video picked from the Files app (iCloud Drive, On My iPhone, USB-C drives)
    /// using security-scoped resource access.
    @discardableResult
    public func importSecurityScopedFile(at url: URL) throws -> ChannelModel {
        isImporting = true
        defer { isImporting = false }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard Self.isSupportedVideoURL(url) else {
            throw ImportError.unsupportedFileType
        }
        return try importFile(at: url, originalName: url.lastPathComponent)
    }

    /// Moves/copies a video file into the library. Separated from PhotosPicker for testability.
    @discardableResult
    public func importFile(at sourceURL: URL, originalName: String? = nil) throws -> ChannelModel {
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let fileName = "video_\(UUID().uuidString).\(ext)"
        let destinationURL = videosDirectory.appendingPathComponent(fileName)

        do {
            // The transferable already made a private temp copy, so move it (avoids doubling disk use).
            if sourceURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            } else {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            }
        } catch {
            throw ImportError.copyFailed(error.localizedDescription)
        }

        let baseName = (originalName as NSString?)?.deletingPathExtension ?? ""
        let channel = ChannelModel(
            name: baseName.isEmpty ? "Local Video \(localVideos.count + 1)" : baseName,
            streamURL: destinationURL,
            groupTitle: "Local Videos"
        )
        localVideos.append(channel)
        saveLocalVideos()
        return channel
    }

    public func deleteVideo(_ channel: ChannelModel) {
        localVideos.removeAll { $0.id == channel.id }
        try? FileManager.default.removeItem(at: channel.streamURL)
        saveLocalVideos()
    }

    /// The app container path changes on every install/update, so absolute file URLs persisted
    /// in UserDefaults go stale and the videos become unplayable. Rebase onto the current folder.
    nonisolated static func rebase(_ storedURL: URL, onto directory: URL) -> URL {
        guard storedURL.isFileURL else { return storedURL }
        return directory.appendingPathComponent(storedURL.lastPathComponent)
    }

    private func saveLocalVideos() {
        if let data = try? JSONEncoder().encode(localVideos) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    private func loadSavedLocalVideos() {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let videos = try? JSONDecoder().decode([ChannelModel].self, from: data) else { return }
        localVideos = videos.compactMap { video in
            var fixed = video
            fixed.streamURL = Self.rebase(video.streamURL, onto: videosDirectory)
            // Drop entries whose file no longer exists instead of showing unplayable rows.
            return FileManager.default.fileExists(atPath: fixed.streamURL.path) ? fixed : nil
        }
        if localVideos.count != videos.count { saveLocalVideos() }
    }
}

public struct MovieFileTransferable: Transferable {
    public let url: URL
    public let originalName: String?

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            // `received.file` is only valid inside this closure, so copy it to a unique temp path
            // (the old code reused the bare file name, so two "IMG_0001.MOV" imports collided).
            let name = received.file.lastPathComponent
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return MovieFileTransferable(url: copy, originalName: name)
        }
    }
}
