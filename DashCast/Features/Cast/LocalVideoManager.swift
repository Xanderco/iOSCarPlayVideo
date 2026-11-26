import AVFoundation
import Foundation
import PhotosUI
import SwiftUI
import UIKit

public struct LocalVideoMetadata: Codable, Equatable, Sendable {
    public var durationSeconds: Double?
    public var fileSizeBytes: Int64
    public var thumbnailFileName: String?

    public init(
        durationSeconds: Double? = nil,
        fileSizeBytes: Int64 = 0,
        thumbnailFileName: String? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.thumbnailFileName = thumbnailFileName
    }
}

@MainActor
public final class LocalVideoManager: ObservableObject {
    public static let shared = LocalVideoManager()

    public enum ImportError: LocalizedError {
        case noVideoData
        case copyFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noVideoData:
                return "The selected item has no video data. If it is stored in iCloud, open it in Photos once to download it and try again."
            case .copyFailed(let reason):
                return "Couldn't save the video: \(reason)"
            }
        }
    }

    @Published public private(set) var localVideos: [ChannelModel] = []
    @Published public private(set) var metadataByID: [String: LocalVideoMetadata] = [:]
    @Published public private(set) var isImporting: Bool = false

    static let defaultsKey = "dashcast_local_imported_videos"
    static let metadataDefaultsKey = "dashcast_local_video_metadata"

    private let videosDirectory: URL
    private let thumbnailsDirectory: URL
    private let defaults: UserDefaults

    public init(
        videosDirectory: URL? = nil,
        thumbnailsDirectory: URL? = nil,
        defaults: UserDefaults = .standard
    ) {
        let resolvedVideosDir = videosDirectory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.videosDirectory = resolvedVideosDir
        self.thumbnailsDirectory = thumbnailsDirectory
            ?? resolvedVideosDir.appendingPathComponent("Thumbnails", isDirectory: true)
        self.defaults = defaults
        try? FileManager.default.createDirectory(at: self.videosDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: self.thumbnailsDirectory, withIntermediateDirectories: true)
        loadSavedLocalVideos()
    }

    /// Total disk usage across all imported local videos and their cached thumbnails.
    public var totalStorageBytes: Int64 {
        localVideos.reduce(Int64(0)) { partial, video in
            let videoBytes = metadataByID[video.id]?.fileSizeBytes ?? Self.fileSize(at: video.streamURL)
            let thumbBytes: Int64
            if let thumbURL = thumbnailURL(for: video) {
                thumbBytes = Self.fileSize(at: thumbURL)
            } else {
                thumbBytes = 0
            }
            return partial + videoBytes + thumbBytes
        }
    }

    public func metadata(for channel: ChannelModel) -> LocalVideoMetadata? {
        metadataByID[channel.id]
    }

    public func thumbnailURL(for channel: ChannelModel) -> URL? {
        guard let fileName = metadataByID[channel.id]?.thumbnailFileName else { return nil }
        let url = thumbnailsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
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
        metadataByID[channel.id] = LocalVideoMetadata(
            durationSeconds: nil,
            fileSizeBytes: Self.fileSize(at: destinationURL),
            thumbnailFileName: nil
        )
        saveLocalVideos()
        saveMetadata()

        Task { [weak self] in
            await self?.refreshMetadata(for: channel)
        }

        return channel
    }

    /// Extracts duration, byte size, and a cached JPEG thumbnail for the given imported video.
    @discardableResult
    public func refreshMetadata(for channel: ChannelModel) async -> LocalVideoMetadata? {
        guard localVideos.contains(where: { $0.id == channel.id }) else { return nil }
        let videoURL = Self.rebase(channel.streamURL, onto: videosDirectory)
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return nil }

        let sizeBytes = Self.fileSize(at: videoURL)
        let thumbFileName = Self.thumbnailFileName(for: channel.id)
        let thumbDestination = thumbnailsDirectory.appendingPathComponent(thumbFileName)
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

        let extracted = await Self.extractMediaMetadata(
            videoURL: videoURL,
            thumbnailDestinationURL: thumbDestination
        )

        // Guard against deletion while async extraction was running.
        guard localVideos.contains(where: { $0.id == channel.id }) else {
            try? FileManager.default.removeItem(at: thumbDestination)
            return nil
        }

        let existing = metadataByID[channel.id]
        let resolvedThumbnailName: String?
        if extracted.wroteThumbnail || FileManager.default.fileExists(atPath: thumbDestination.path) {
            resolvedThumbnailName = thumbFileName
        } else {
            resolvedThumbnailName = existing?.thumbnailFileName
        }

        let updated = LocalVideoMetadata(
            durationSeconds: extracted.durationSeconds ?? existing?.durationSeconds,
            fileSizeBytes: sizeBytes,
            thumbnailFileName: resolvedThumbnailName
        )
        metadataByID[channel.id] = updated
        saveMetadata()
        return updated
    }

    public func deleteVideo(_ channel: ChannelModel) {
        localVideos.removeAll { $0.id == channel.id }
        try? FileManager.default.removeItem(at: channel.streamURL)
        removeCachedThumbnail(for: channel.id)
        metadataByID.removeValue(forKey: channel.id)
        saveLocalVideos()
        saveMetadata()
    }

    /// Deletes all imported local videos and all cached thumbnails to reclaim storage.
    public func deleteAllVideos() {
        for video in localVideos {
            try? FileManager.default.removeItem(at: video.streamURL)
            removeCachedThumbnail(for: video.id)
        }
        localVideos.removeAll()
        metadataByID.removeAll()
        cleanupOrphanedThumbnails()
        saveLocalVideos()
        saveMetadata()
    }

    /// Removes any cached thumbnail files not referenced by an active imported video.
    public func cleanupOrphanedThumbnails() {
        let activeFileNames = Set(metadataByID.values.compactMap(\.thumbnailFileName))
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: thumbnailsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in contents where !activeFileNames.contains(fileURL.lastPathComponent) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func removeCachedThumbnail(for videoID: String) {
        if let storedName = metadataByID[videoID]?.thumbnailFileName {
            try? FileManager.default.removeItem(at: thumbnailsDirectory.appendingPathComponent(storedName))
        }
        let deterministicURL = thumbnailsDirectory.appendingPathComponent(Self.thumbnailFileName(for: videoID))
        try? FileManager.default.removeItem(at: deterministicURL)
    }

    /// The app container path changes on every install/update, so absolute file URLs persisted
    /// in UserDefaults go stale and the videos become unplayable. Rebase onto the current folder.
    nonisolated static func rebase(_ storedURL: URL, onto directory: URL) -> URL {
        guard storedURL.isFileURL else { return storedURL }
        return directory.appendingPathComponent(storedURL.lastPathComponent)
    }

    nonisolated static func thumbnailFileName(for videoID: String) -> String {
        let safeID = videoID.replacingOccurrences(of: "/", with: "_")
        return "thumb_\(safeID).jpg"
    }

    nonisolated static func fileSize(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let number = attributes[.size] as? NSNumber else {
            return 0
        }
        return number.int64Value
    }

    nonisolated public static func formatDuration(_ seconds: Double?) -> String? {
        guard let seconds, seconds.isFinite, seconds > 0 else { return nil }
        let totalSeconds = max(1, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    nonisolated public static func formatByteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }

    nonisolated static func extractMediaMetadata(
        videoURL: URL,
        thumbnailDestinationURL: URL
    ) async -> (durationSeconds: Double?, wroteThumbnail: Bool) {
        let asset = AVURLAsset(url: videoURL)

        var durationSeconds: Double?
        if let cmDuration = try? await asset.load(.duration) {
            let secs = CMTimeGetSeconds(cmDuration)
            if secs.isFinite && secs > 0 {
                durationSeconds = secs
            }
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)

        let targetSeconds: Double
        if let durationSeconds, durationSeconds > 1.0 {
            targetSeconds = min(1.0, durationSeconds * 0.1)
        } else {
            targetSeconds = 0
        }
        let primaryTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)

        var cgImage: CGImage?
        if let result = try? await generator.image(at: primaryTime) {
            cgImage = result.image
        } else if targetSeconds > 0, let fallback = try? await generator.image(at: .zero) {
            cgImage = fallback.image
        }

        var wroteThumbnail = false
        if let cgImage, let jpegData = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.78) {
            do {
                try jpegData.write(to: thumbnailDestinationURL, options: .atomic)
                wroteThumbnail = true
            } catch {
                wroteThumbnail = false
            }
        }

        return (durationSeconds, wroteThumbnail)
    }

    private func saveLocalVideos() {
        if let data = try? JSONEncoder().encode(localVideos) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    private func saveMetadata() {
        if let data = try? JSONEncoder().encode(metadataByID) {
            defaults.set(data, forKey: Self.metadataDefaultsKey)
        }
    }

    private func loadSavedLocalVideos() {
        if let metadataData = defaults.data(forKey: Self.metadataDefaultsKey),
           let decodedMetadata = try? JSONDecoder().decode([String: LocalVideoMetadata].self, from: metadataData) {
            metadataByID = decodedMetadata
        }

        guard let data = defaults.data(forKey: Self.defaultsKey),
              let videos = try? JSONDecoder().decode([ChannelModel].self, from: data) else {
            cleanupOrphanedThumbnails()
            return
        }

        localVideos = videos.compactMap { video in
            var fixed = video
            fixed.streamURL = Self.rebase(video.streamURL, onto: videosDirectory)
            // Drop entries whose file no longer exists instead of showing unplayable rows.
            return FileManager.default.fileExists(atPath: fixed.streamURL.path) ? fixed : nil
        }

        let validIDs = Set(localVideos.map(\.id))
        let originalMetadataCount = metadataByID.count
        metadataByID = metadataByID.filter { validIDs.contains($0.key) }

        var needsBackfill: [ChannelModel] = []
        for video in localVideos {
            let size = Self.fileSize(at: video.streamURL)
            var meta = metadataByID[video.id] ?? LocalVideoMetadata(fileSizeBytes: size)
            if meta.fileSizeBytes != size {
                meta.fileSizeBytes = size
            }
            if let thumbName = meta.thumbnailFileName {
                let thumbPath = thumbnailsDirectory.appendingPathComponent(thumbName).path
                if !FileManager.default.fileExists(atPath: thumbPath) {
                    meta.thumbnailFileName = nil
                }
            }
            metadataByID[video.id] = meta
            if meta.durationSeconds == nil || meta.thumbnailFileName == nil {
                needsBackfill.append(video)
            }
        }

        cleanupOrphanedThumbnails()
        if localVideos.count != videos.count { saveLocalVideos() }
        if metadataByID.count != originalMetadataCount || !localVideos.isEmpty { saveMetadata() }

        if !needsBackfill.isEmpty {
            Task { [weak self] in
                for video in needsBackfill {
                    await self?.refreshMetadata(for: video)
                }
            }
        }
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
