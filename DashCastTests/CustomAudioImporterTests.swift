import XCTest
import AVFoundation
@testable import DashCast

final class CustomAudioImporterTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Clean up any remaining test custom sounds
        let catalog = SoundCatalogService.shared
        for sound in catalog.customSounds {
            try? catalog.deleteCustomSound(id: sound.id)
        }
    }

    // MARK: - Synthetic Audio File Generator

    private func makeTestAudioFile(
        duration: Double = 0.5,
        frequency: Double = 440.0,
        amplitude: Float = 0.4
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).wav")

        let sampleRate = 44100.0
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "CustomAudioImporterTests", code: -1, userInfo: nil)
        }

        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        let frameCount = UInt32(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "CustomAudioImporterTests", code: -2, userInfo: nil)
        }
        buffer.frameLength = frameCount

        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                channelData[i] = Float(sin(2.0 * .pi * frequency * t)) * amplitude
            }
        }

        try audioFile.write(from: buffer)
        return url
    }

    // MARK: - Waveform Analysis Tests

    func testDurationFormatting() {
        XCTAssertEqual(AudioWaveformService.formatDuration(seconds: 0.0), "0:00")
        XCTAssertEqual(AudioWaveformService.formatDuration(seconds: 4.2), "0:04")
        XCTAssertEqual(AudioWaveformService.formatDuration(seconds: 59.8), "1:00")
        XCTAssertEqual(AudioWaveformService.formatDuration(seconds: 125.0), "2:05")
    }

    func testSyntheticWaveformGeneration() {
        for category in SoundCategory.allCases {
            let samples = AudioWaveformService.syntheticWaveform(frequencyHz: 520, category: category, sampleCount: 32)
            XCTAssertEqual(samples.count, 32, "Category \(category) should generate 32 samples")
            for sample in samples {
                XCTAssertGreaterThanOrEqual(sample, 0.05)
                XCTAssertLessThanOrEqual(sample, 1.0)
            }
        }
    }

    func testAudioWaveformAnalysisAndNormalization() throws {
        let testWav = try makeTestAudioFile(duration: 1.0, frequency: 300.0, amplitude: 0.25)
        defer { try? FileManager.default.removeItem(at: testWav) }

        let result = try AudioWaveformService.analyzeAudio(url: testWav, sampleCount: 32)
        XCTAssertGreaterThan(result.durationSeconds, 0.8)
        XCTAssertLessThan(result.durationSeconds, 1.2)
        XCTAssertEqual(result.waveformSamples.count, 32)
        XCTAssertGreaterThan(result.peakAmplitude, 0.15)
        XCTAssertLessThanOrEqual(result.peakAmplitude, 0.35)

        // Low amplitude (0.25) should result in normalization gain > 1.0 to reach 0.85 target
        XCTAssertGreaterThan(result.normalizationGain, 1.5, "Volume normalization should boost quiet audio")
        XCTAssertLessThanOrEqual(result.normalizationGain, 3.0)
    }

    // MARK: - Sound Catalog Import Tests

    @MainActor
    func testCustomAudioImportLifecycle() async throws {
        let catalog = SoundCatalogService.shared
        let initialCount = catalog.sounds.count

        let testWav = try makeTestAudioFile(duration: 0.8, frequency: 220.0, amplitude: 0.5)
        defer { try? FileManager.default.removeItem(at: testWav) }

        // Import
        let imported = try await catalog.importCustomAudio(
            from: testWav,
            preferredTitle: "Supercharged V8 Idle"
        )

        XCTAssertTrue(imported.isCustom)
        XCTAssertEqual(imported.category, .custom)
        XCTAssertEqual(imported.title, "Supercharged V8 Idle")
        XCTAssertNotNil(imported.relativeFilePath)
        XCTAssertNotNil(imported.fileURL)
        if let fileURL = imported.fileURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        }
        XCTAssertEqual(imported.waveformSamples.count, 32)
        XCTAssertGreaterThan(imported.normalizationGain, 0.0)

        // Check catalog integration
        XCTAssertEqual(catalog.sounds.count, initialCount + 1)
        XCTAssertTrue(catalog.customSounds.contains(where: { $0.id == imported.id }))
        XCTAssertNotNil(catalog.sound(for: imported.id))

        let customCategoryList = catalog.sounds(for: .custom)
        XCTAssertTrue(customCategoryList.contains(where: { $0.id == imported.id }))

        // Delete
        try catalog.deleteCustomSound(id: imported.id)
        XCTAssertNil(catalog.sound(for: imported.id))
        XCTAssertFalse(catalog.customSounds.contains(where: { $0.id == imported.id }))
        if let fileURL = imported.fileURL {
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @MainActor
    func testCustomAudioRejectsNonAudioExtension() async throws {
        let catalog = SoundCatalogService.shared
        let tempTxt = FileManager.default.temporaryDirectory.appendingPathComponent("fake.txt")
        try "Not an audio file".write(to: tempTxt, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempTxt) }

        do {
            try await catalog.importCustomAudio(from: tempTxt)
            XCTFail("Importing non-audio file must throw SoundImportError.unsupportedAudioFormat")
        } catch let error as SoundImportError {
            XCTAssertEqual(error, .unsupportedAudioFormat)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - CarPlay Connection Chime Service Tests

    @MainActor
    func testCarPlayConnectionChimeService() {
        let service = CarPlayConnectionChimeService.shared

        service.handleCarPlayConnected()
        XCTAssertTrue(service.isConnectedToCar)
        XCTAssertNotNil(service.lastTriggeredDate)
        XCTAssertEqual(service.lastTriggerSource, .carPlayTemplate)

        service.handleCarPlayDisconnected()
        XCTAssertFalse(service.isConnectedToCar)
        XCTAssertNotNil(service.lastTriggeredDate)
        XCTAssertEqual(service.lastTriggerSource, .carPlayTemplate)
    }

    // MARK: - Sound Player Audio Session Configuration

    @MainActor
    func testAudioSessionConfigurationForChime() throws {
        let player = SoundPlayerEngine.shared
        XCTAssertNoThrow(try player.configureAudioSession(duckOthers: true))

        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playback)
        XCTAssertTrue(session.categoryOptions.contains(.duckOthers))
    }

    @MainActor
    func testCustomSoundPlaybackInvocation() async throws {
        let testWav = try makeTestAudioFile(duration: 0.3, frequency: 500.0, amplitude: 0.4)
        defer { try? FileManager.default.removeItem(at: testWav) }

        let catalog = SoundCatalogService.shared
        let imported = try await catalog.importCustomAudio(from: testWav, preferredTitle: "Test Chime")
        defer { try? catalog.deleteCustomSound(id: imported.id) }

        let engine = SoundPlayerEngine.shared
        engine.play(sound: imported)
        XCTAssertEqual(engine.currentlyPlayingId, imported.id)

        engine.stop()
        XCTAssertNil(engine.currentlyPlayingId)
    }
}
