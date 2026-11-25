import XCTest
import AVFoundation
@testable import DashCast

final class MediaTrackSelectionTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "MediaTrackSelectionTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        if let suiteName {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
    }

    // MARK: - Track Filtering

    func testFilterOptionsExcludesForcedSubtitlesAndSyntheticOffAndDuplicates() {
        let rawSubtitles: [MediaTrackOption] = [
            .subtitlesOff,
            MediaTrackOption(id: "s0", displayName: "English (Forced)", languageCode: "en", isForcedSubtitle: true, optionIndex: 0),
            MediaTrackOption(id: "s1", displayName: "English", languageCode: "en", isForcedSubtitle: false, optionIndex: 1),
            MediaTrackOption(id: "s2", displayName: "English", languageCode: "EN", isForcedSubtitle: false, optionIndex: 2),
            MediaTrackOption(id: "s3", displayName: "English SDH", languageCode: "en", isForcedSubtitle: false, isSDH: true, optionIndex: 3),
            MediaTrackOption(id: "s4", displayName: "   ", languageCode: nil, optionIndex: 4),
            MediaTrackOption(id: "s5", displayName: "Español", languageCode: "es-419", optionIndex: 5)
        ]

        let filtered = MediaTrackSelectionPolicy.filterOptions(rawSubtitles, kind: .subtitle)
        XCTAssertEqual(filtered.map(\.id), ["s1", "s3", "s5"])

        let includingForced = MediaTrackSelectionPolicy.filterOptions(
            rawSubtitles,
            kind: .subtitle,
            includeForcedSubtitles: true
        )
        XCTAssertEqual(includingForced.map(\.id), ["s0", "s1", "s3", "s5"])
    }

    func testFilterAudioOptionsPreservesDistinctLanguagesAndNormalizes() {
        let rawAudio: [MediaTrackOption] = [
            MediaTrackOption(id: "a0", displayName: "English", languageCode: "en-US", optionIndex: 0),
            MediaTrackOption(id: "a1", displayName: "Español (Latinoamérica)", languageCode: "es_419", optionIndex: 1),
            MediaTrackOption(id: "a2", displayName: "Español (Latinoamérica)", languageCode: "es-419", optionIndex: 2)
        ]

        let filtered = MediaTrackSelectionPolicy.filterOptions(rawAudio, kind: .audio)
        XCTAssertEqual(filtered.map(\.id), ["a0", "a1"])
        XCTAssertEqual(MediaTrackSelectionPolicy.normalizedLanguageCode("es_419"), "es-419")
        XCTAssertEqual(MediaTrackSelectionPolicy.baseLanguageCode("es_419"), "es")
    }

    // MARK: - Off Subtitle Handling

    func testSelectingOffSubtitlesPersistsExplicitOffAndSuppressesAutoMatch() {
        let policy = MediaTrackSelectionPolicy(defaults: defaults)
        let spanishSub = MediaTrackOption(id: "s1", displayName: "Español", languageCode: "es", optionIndex: 0)
        let englishSub = MediaTrackOption(id: "s2", displayName: "English", languageCode: "en", optionIndex: 1)

        policy.recordSubtitleSelection(spanishSub)
        XCTAssertEqual(policy.preferredSubtitleLanguageCode, "es")
        XCTAssertFalse(policy.areSubtitlesExplicitlyOff)
        XCTAssertEqual(policy.resolveAutoSubtitleOption(from: [englishSub, spanishSub])?.id, "s1")

        // User explicitly turns subtitles Off
        policy.recordSubtitleSelection(nil)
        XCTAssertTrue(policy.areSubtitlesExplicitlyOff)
        XCTAssertNil(policy.preferredSubtitleLanguageCode)
        XCTAssertNil(policy.resolveAutoSubtitleOption(from: [englishSub, spanishSub]))

        // Re-verify synthetic .subtitlesOff option produces identical behavior
        policy.recordSubtitleSelection(englishSub)
        XCTAssertEqual(policy.preferredSubtitleLanguageCode, "en")
        policy.recordSubtitleSelection(.subtitlesOff)
        XCTAssertTrue(policy.areSubtitlesExplicitlyOff)
        XCTAssertNil(policy.resolveAutoSubtitleOption(from: [englishSub, spanishSub]))
    }

    // MARK: - Preferred Language Auto-Matching

    func testPreferredLanguageAutoMatchingExactAndBaseFallback() {
        let policy = MediaTrackSelectionPolicy(defaults: defaults)
        let audioTracks: [MediaTrackOption] = [
            MediaTrackOption(id: "a0", displayName: "English", languageCode: "en", optionIndex: 0),
            MediaTrackOption(id: "a1", displayName: "Español", languageCode: "es-ES", optionIndex: 1),
            MediaTrackOption(id: "a2", displayName: "Español (Latinoamérica)", languageCode: "es-419", optionIndex: 2)
        ]

        // Exact regional match preferred over sibling dialect
        policy.recordAudioSelection(audioTracks[2])
        XCTAssertEqual(policy.resolveAutoAudioOption(from: audioTracks)?.id, "a2")

        // Base-language fallback when exact region is missing in next video
        let nextVideoTracks: [MediaTrackOption] = [
            MediaTrackOption(id: "b0", displayName: "English", languageCode: "en", optionIndex: 0),
            MediaTrackOption(id: "b1", displayName: "Spanish", languageCode: "es", optionIndex: 1)
        ]
        XCTAssertEqual(policy.resolveAutoAudioOption(from: nextVideoTracks)?.id, "b1")
    }

    func testSubtitleAutoMatchPrefersNonSDHOnBaseLanguageTie() {
        let policy = MediaTrackSelectionPolicy(defaults: defaults)
        policy.preferredSubtitleLanguageCode = "en-GB"

        let tracks: [MediaTrackOption] = [
            MediaTrackOption(id: "s0", displayName: "English SDH", languageCode: "en-US", isSDH: true, optionIndex: 0),
            MediaTrackOption(id: "s1", displayName: "English", languageCode: "en-US", isSDH: false, optionIndex: 1)
        ]
        XCTAssertEqual(policy.resolveAutoSubtitleOption(from: tracks)?.id, "s1")
    }

    // MARK: - Persistence & VideoPlayerService Integration

    @MainActor
    func testVideoPlayerServicePersistsTrackPreferencesAndCleansUpOnStop() {
        let service1 = VideoPlayerService(handlesRemoteCommands: false, defaults: defaults)
        XCTAssertFalse(service1.hasSavedTrackPreferences)

        let frAudio = MediaTrackOption(id: "a-fr", displayName: "Français", languageCode: "fr", optionIndex: 0)
        let esSub = MediaTrackOption(id: "s-es", displayName: "Español", languageCode: "es", optionIndex: 0)

        service1.selectAudioTrack(frAudio)
        service1.selectSubtitleTrack(esSub)
        XCTAssertTrue(service1.hasSavedTrackPreferences)
        XCTAssertEqual(service1.selectedAudioTrack?.id, "a-fr")
        XCTAssertEqual(service1.selectedSubtitleTrack?.id, "s-es")

        // Second service instance backed by same defaults inherits saved preferences
        let service2 = VideoPlayerService(handlesRemoteCommands: false, defaults: defaults)
        XCTAssertTrue(service2.hasSavedTrackPreferences)
        XCTAssertEqual(service2.trackSelectionPolicy.preferredAudioLanguageCode, "fr")
        XCTAssertEqual(service2.trackSelectionPolicy.preferredSubtitleLanguageCode, "es")

        service2.selectSubtitleTrack(.subtitlesOff)
        XCTAssertNil(service2.selectedSubtitleTrack)
        XCTAssertTrue(service2.trackSelectionPolicy.areSubtitlesExplicitlyOff)

        service2.clearTrackPreferences()
        XCTAssertFalse(service2.hasSavedTrackPreferences)
        XCTAssertFalse(service2.trackSelectionPolicy.hasSavedPreferences)
    }

    @MainActor
    func testVideoPlayerServiceDiscoversBundledVideoTracksAndResetsOnStop() async throws {
        let demoURL = try XCTUnwrap(IPTVParser.samplePlaylist.first?.streamURL)
        let service = VideoPlayerService(handlesRemoteCommands: false, defaults: defaults)
        service.load(channel: ChannelModel(name: "Demo", streamURL: demoURL, groupTitle: "Demo Videos"))

        let deadline = Date().addingTimeInterval(10)
        while service.player.currentItem?.status != .readyToPlay && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(service.player.currentItem?.status, .readyToPlay)

        service.refreshMediaTracks()
        try await Task.sleep(nanoseconds: 150_000_000)

        // Turning subtitles off on a stream without subtitles must not error or stall
        service.selectSubtitleTrack(nil)
        XCTAssertNil(service.playbackError)
        XCTAssertNil(service.selectedSubtitleTrack)

        service.stop()
        XCTAssertTrue(service.availableAudioTracks.isEmpty)
        XCTAssertTrue(service.availableSubtitleTracks.isEmpty)
        XCTAssertNil(service.selectedAudioTrack)
        XCTAssertNil(service.selectedSubtitleTrack)
    }
}
