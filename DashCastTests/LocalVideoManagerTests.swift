import XCTest
import UIKit
@testable import DashCast

final class LocalVideoManagerTests: XCTestCase {

    private func makeTestEnvironment() throws -> (
        root: URL,
        videosDir: URL,
        thumbsDir: URL,
        defaults: UserDefaults,
        suiteName: String
    ) {
        let suiteName = "LocalVideoManagerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalVideoManagerTests-\(UUID().uuidString)", isDirectory: true)
        let videosDir = root.appendingPathComponent("Videos", isDirectory: true)
        let thumbsDir = root.appendingPathComponent("Thumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: thumbsDir, withIntermediateDirectories: true)
        return (root, videosDir, thumbsDir, defaults, suiteName)
    }

    private func bundledSampleVideoURL() throws -> URL {
        if let url = Bundle.main.url(forResource: "night_drive", withExtension: "mp4") {
            return url
        }
        let fallback = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DashCast/Resources/Videos/night_drive.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fallback.path), "Sample MP4 missing at \(fallback.path)")
        return fallback
    }

    @MainActor
    func testImportExtractsMetadataAndCleansUpThumbnailOnDelete() async throws {
        let env = try makeTestEnvironment()
        defer {
            try? FileManager.default.removeItem(at: env.root)
            env.defaults.removePersistentDomain(forName: env.suiteName)
        }

        let sampleURL = try bundledSampleVideoURL()
        let expectedVideoSize = Int64(try Data(contentsOf: sampleURL).count)
        XCTAssertGreaterThan(expectedVideoSize, 0)

        let manager = LocalVideoManager(
            videosDirectory: env.videosDir,
            thumbnailsDirectory: env.thumbsDir,
            defaults: env.defaults
        )

        let channel = try manager.importFile(at: sampleURL, originalName: "night_drive.mp4")
        let initialMeta = try XCTUnwrap(manager.metadata(for: channel))
        XCTAssertEqual(initialMeta.fileSizeBytes, expectedVideoSize)
        XCTAssertGreaterThanOrEqual(manager.totalStorageBytes, expectedVideoSize)

        let refreshed = await manager.refreshMetadata(for: channel)
        let enrichedMeta = try XCTUnwrap(refreshed)
        XCTAssertEqual(enrichedMeta.fileSizeBytes, expectedVideoSize)
        XCTAssertGreaterThan(enrichedMeta.durationSeconds ?? 0, 0)

        let thumbURL = try XCTUnwrap(manager.thumbnailURL(for: channel))
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbURL.path))
        let thumbData = try Data(contentsOf: thumbURL)
        XCTAssertGreaterThan(thumbData.count, 100)
        // JPEG SOI marker: 0xFF 0xD8
        XCTAssertEqual(Array(thumbData.prefix(2)), [0xFF, 0xD8])
        XCTAssertNotNil(UIImage(data: thumbData))
        XCTAssertEqual(manager.totalStorageBytes, expectedVideoSize + Int64(thumbData.count))

        // Persistence across reload keeps metadata and thumbnail intact.
        let reloaded = LocalVideoManager(
            videosDirectory: env.videosDir,
            thumbnailsDirectory: env.thumbsDir,
            defaults: env.defaults
        )
        XCTAssertEqual(reloaded.localVideos.count, 1)
        XCTAssertEqual(reloaded.metadata(for: channel)?.fileSizeBytes, expectedVideoSize)
        XCTAssertNotNil(reloaded.thumbnailURL(for: channel))

        // Delete cleans up both the video file and cached JPEG thumbnail.
        reloaded.deleteVideo(channel)
        XCTAssertTrue(reloaded.localVideos.isEmpty)
        XCTAssertNil(reloaded.metadata(for: channel))
        XCTAssertNil(reloaded.thumbnailURL(for: channel))
        XCTAssertEqual(reloaded.totalStorageBytes, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: channel.streamURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: thumbURL.path))
    }

    @MainActor
    func testDeleteAllVideosRemovesAllFilesAndThumbnails() async throws {
        let env = try makeTestEnvironment()
        defer {
            try? FileManager.default.removeItem(at: env.root)
            env.defaults.removePersistentDomain(forName: env.suiteName)
        }

        let sampleURL = try bundledSampleVideoURL()
        let manager = LocalVideoManager(
            videosDirectory: env.videosDir,
            thumbnailsDirectory: env.thumbsDir,
            defaults: env.defaults
        )

        let first = try manager.importFile(at: sampleURL, originalName: "clip1.mp4")
        let second = try manager.importFile(at: sampleURL, originalName: "clip2.mp4")
        _ = await manager.refreshMetadata(for: first)
        _ = await manager.refreshMetadata(for: second)

        let firstThumb = try XCTUnwrap(manager.thumbnailURL(for: first))
        let secondThumb = try XCTUnwrap(manager.thumbnailURL(for: second))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstThumb.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondThumb.path))

        manager.deleteAllVideos()

        XCTAssertTrue(manager.localVideos.isEmpty)
        XCTAssertTrue(manager.metadataByID.isEmpty)
        XCTAssertEqual(manager.totalStorageBytes, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.streamURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.streamURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstThumb.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondThumb.path))
    }

    @MainActor
    func testOrphanedThumbnailsAreCleanedUpOnInit() throws {
        let env = try makeTestEnvironment()
        defer {
            try? FileManager.default.removeItem(at: env.root)
            env.defaults.removePersistentDomain(forName: env.suiteName)
        }

        let orphanThumb = env.thumbsDir.appendingPathComponent("thumb_orphan.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: orphanThumb)
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanThumb.path))

        _ = LocalVideoManager(
            videosDirectory: env.videosDir,
            thumbnailsDirectory: env.thumbsDir,
            defaults: env.defaults
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanThumb.path))
    }

    func testFormatDurationAndByteCount() {
        XCTAssertNil(LocalVideoManager.formatDuration(nil))
        XCTAssertNil(LocalVideoManager.formatDuration(0))
        XCTAssertNil(LocalVideoManager.formatDuration(-3))
        XCTAssertNil(LocalVideoManager.formatDuration(.nan))
        XCTAssertEqual(LocalVideoManager.formatDuration(0.4), "0:01")
        XCTAssertEqual(LocalVideoManager.formatDuration(12.4), "0:12")
        XCTAssertEqual(LocalVideoManager.formatDuration(65), "1:05")
        XCTAssertEqual(LocalVideoManager.formatDuration(3661), "1:01:01")

        XCTAssertFalse(LocalVideoManager.formatByteCount(0).isEmpty)
        XCTAssertFalse(LocalVideoManager.formatByteCount(1_048_576).isEmpty)
    }
}
