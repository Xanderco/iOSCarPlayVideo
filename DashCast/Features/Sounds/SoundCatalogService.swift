import Foundation
import SwiftUI
import Combine

public enum SoundCategory: String, CaseIterable, Identifiable, Codable {
    case all = "All"
    case custom = "Custom"
    case engine = "Engine"
    case voices = "Voices"
    case futuristic = "Futuristic"
    case chimes = "Chimes"
    case cinematic = "Cinematic"

    public var id: String { rawValue }
}

public struct SoundEffectItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let category: SoundCategory
    public let durationString: String
    public let frequencyHz: Double // For synthesizer audio preview
    public let color: Color
    public let relativeFilePath: String?
    public let isCustom: Bool
    public let waveformSamples: [Float]
    public let normalizationGain: Float

    public var fileURL: URL? {
        guard let relativeFilePath else { return nil }
        return SoundCatalogService.customSoundsDirectory.appendingPathComponent(relativeFilePath)
    }

    public init(
        id: String,
        title: String,
        category: SoundCategory,
        durationString: String = "0:02",
        frequencyHz: Double = 440,
        color: Color = .dashGreen,
        relativeFilePath: String? = nil,
        isCustom: Bool = false,
        waveformSamples: [Float] = [],
        normalizationGain: Float = 1.0
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.durationString = durationString
        self.frequencyHz = frequencyHz
        self.color = color
        self.relativeFilePath = relativeFilePath
        self.isCustom = isCustom
        self.waveformSamples = waveformSamples.isEmpty
            ? AudioWaveformService.syntheticWaveform(frequencyHz: frequencyHz, category: category)
            : waveformSamples
        self.normalizationGain = normalizationGain
    }
}

public struct CustomSoundMetadata: Codable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let categoryRawValue: String
    public let durationString: String
    public let frequencyHz: Double
    public let relativeFilePath: String
    public let waveformSamples: [Float]
    public let normalizationGain: Float
    public let createdAt: Date

    public init(
        id: String,
        title: String,
        categoryRawValue: String,
        durationString: String,
        frequencyHz: Double,
        relativeFilePath: String,
        waveformSamples: [Float],
        normalizationGain: Float,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.categoryRawValue = categoryRawValue
        self.durationString = durationString
        self.frequencyHz = frequencyHz
        self.relativeFilePath = relativeFilePath
        self.waveformSamples = waveformSamples
        self.normalizationGain = normalizationGain
        self.createdAt = createdAt
    }
}

public enum SoundImportError: Error, LocalizedError {
    case unsupportedAudioFormat
    case fileAccessDenied
    case copyFailed
    case analysisFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedAudioFormat:
            return "Unsupported audio format. Please choose a WAV, MP3, or M4A file."
        case .fileAccessDenied:
            return "Could not access the selected audio file."
        case .copyFailed:
            return "Failed to copy the audio file to DashCast sound library."
        case .analysisFailed:
            return "Failed to extract waveform or audio properties from the file."
        }
    }
}

public final class SoundCatalogService: ObservableObject {
    public static let shared = SoundCatalogService()

    @Published public private(set) var customSounds: [SoundEffectItem] = []

    public static var customSoundsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let customDir = docs.appendingPathComponent("CustomSounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: customDir.path) {
            try? FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
        }
        return customDir
    }

    private var metadataFileURL: URL {
        Self.customSoundsDirectory.appendingPathComponent("custom_sounds_manifest.json")
    }

    public let presetSounds: [SoundEffectItem] = [
        // Connection & Futuristic
        SoundEffectItem(id: "jet_startup", title: "Jet Startup", category: .futuristic, durationString: "0:03", frequencyHz: 520, color: .dashYellow),
        SoundEffectItem(id: "hyperspace", title: "Hyperspace Jump", category: .futuristic, durationString: "0:02", frequencyHz: 680, color: .dashBlue),
        SoundEffectItem(id: "electric_warp", title: "Electric Warp Pulse", category: .futuristic, durationString: "0:02", frequencyHz: 840, color: .dashAmber),

        // Disconnection & Chimes
        SoundEffectItem(id: "airline_dingy", title: "Airline Dingy", category: .chimes, durationString: "0:02", frequencyHz: 600, color: .dashOrange),
        SoundEffectItem(id: "luxury_chime", title: "Luxury Sedan Chime", category: .chimes, durationString: "0:03", frequencyHz: 750, color: .dashGold),
        SoundEffectItem(id: "crystal_ping", title: "Crystal Ping", category: .chimes, durationString: "0:01", frequencyHz: 920, color: .dashGreen),

        // Voices
        SoundEffectItem(id: "welcome_sir", title: "Welcome Back Sir", category: .voices, durationString: "0:02", frequencyHz: 350, color: .dashGold),
        SoundEffectItem(id: "welcome_traveler", title: "Welcome Traveler", category: .voices, durationString: "0:01", frequencyHz: 420, color: .dashGreen),
        SoundEffectItem(id: "ready_for_launch", title: "Ready for Launch", category: .voices, durationString: "0:02", frequencyHz: 480, color: .dashYellow),
        SoundEffectItem(id: "captain_aboard", title: "Good Morning Captain", category: .voices, durationString: "0:02", frequencyHz: 400, color: .dashAmber),

        // Engine
        SoundEffectItem(id: "sport_startup", title: "Sport Car Startup - 1", category: .engine, durationString: "0:05", frequencyHz: 280, color: .dashRed),
        SoundEffectItem(id: "v8_supercharged", title: "V8 Supercharged Idle", category: .engine, durationString: "0:04", frequencyHz: 220, color: .dashOrange),
        SoundEffectItem(id: "turbo_spool", title: "Twin Turbo Spool", category: .engine, durationString: "0:03", frequencyHz: 550, color: .dashYellow),
        SoundEffectItem(id: "v12_rev", title: "V12 Screamer Rev", category: .engine, durationString: "0:04", frequencyHz: 650, color: .dashRed),

        // Cinematic
        SoundEffectItem(id: "piano_elegance", title: "Piano Cinematic", category: .cinematic, durationString: "0:04", frequencyHz: 523, color: .dashGold),
        SoundEffectItem(id: "deep_bass_drop", title: "Deep Bass Drop", category: .cinematic, durationString: "0:03", frequencyHz: 180, color: .dashAmber),
        SoundEffectItem(id: "orchestral_fanfare", title: "Orchestral Fanfare", category: .cinematic, durationString: "0:03", frequencyHz: 600, color: .dashGreen)
    ]

    public var sounds: [SoundEffectItem] {
        presetSounds + customSounds
    }

    public init() {
        loadCustomSounds()
    }

    public func sound(for id: String) -> SoundEffectItem? {
        sounds.first { $0.id == id }
    }

    public func sounds(for category: SoundCategory) -> [SoundEffectItem] {
        if category == .all {
            return sounds
        }
        return sounds.filter { $0.category == category }
    }

    // MARK: - Custom Audio Import & Management

    /// Imports an audio file (WAV, MP3, M4A) from an external URL, saves it to sandbox, extracts waveform/normalization, and persists metadata.
    @discardableResult
    public func importCustomAudio(
        from sourceURL: URL,
        preferredTitle: String? = nil,
        category: SoundCategory = .custom
    ) async throws -> SoundEffectItem {
        let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let ext = sourceURL.pathExtension.lowercased()
        let allowedExtensions = ["wav", "mp3", "m4a", "aac", "caf", "aif", "aiff"]
        guard allowedExtensions.contains(ext) else {
            throw SoundImportError.unsupportedAudioFormat
        }

        let uniqueId = "custom_\(UUID().uuidString.prefix(8))"
        let filename = "\(uniqueId).\(ext)"
        let destinationURL = Self.customSoundsDirectory.appendingPathComponent(filename)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw SoundImportError.copyFailed
        }

        // Analyze audio for duration, waveforms, and volume normalization
        let analysis: AudioAnalysisResult
        do {
            analysis = try AudioWaveformService.analyzeAudio(url: destinationURL)
        } catch {
            // Cleanup on analysis failure
            try? FileManager.default.removeItem(at: destinationURL)
            throw SoundImportError.analysisFailed
        }

        let rawTitle = preferredTitle ?? sourceURL.deletingPathExtension().lastPathComponent
        let cleanTitle = rawTitle.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ").capitalized

        let newItem = SoundEffectItem(
            id: uniqueId,
            title: cleanTitle.isEmpty ? "Custom Audio Clip" : cleanTitle,
            category: category,
            durationString: analysis.durationString,
            frequencyHz: 440,
            color: .dashYellow,
            relativeFilePath: filename,
            isCustom: true,
            waveformSamples: analysis.waveformSamples,
            normalizationGain: analysis.normalizationGain
        )

        await MainActor.run {
            self.customSounds.insert(newItem, at: 0)
            self.saveCustomSoundsMetadata()
        }

        return newItem
    }

    /// Deletes a custom sound item and removes its underlying audio file.
    public func deleteCustomSound(id: String) throws {
        guard let item = customSounds.first(where: { $0.id == id }) else { return }

        if let fileURL = item.fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        customSounds.removeAll { $0.id == id }
        saveCustomSoundsMetadata()
    }

    // MARK: - Persistence

    private func saveCustomSoundsMetadata() {
        let metadataList = customSounds.compactMap { item -> CustomSoundMetadata? in
            guard let relativePath = item.relativeFilePath else { return nil }
            return CustomSoundMetadata(
                id: item.id,
                title: item.title,
                categoryRawValue: item.category.rawValue,
                durationString: item.durationString,
                frequencyHz: item.frequencyHz,
                relativeFilePath: relativePath,
                waveformSamples: item.waveformSamples,
                normalizationGain: item.normalizationGain
            )
        }

        do {
            let data = try JSONEncoder().encode(metadataList)
            try data.write(to: metadataFileURL, options: .atomic)
        } catch {
            print("Failed to save custom sound metadata: \(error)")
        }
    }

    private func loadCustomSounds() {
        guard FileManager.default.fileExists(atPath: metadataFileURL.path),
              let data = try? Data(contentsOf: metadataFileURL),
              let metadataList = try? JSONDecoder().decode([CustomSoundMetadata].self, from: data) else {
            return
        }

        self.customSounds = metadataList.compactMap { meta in
            let fileURL = Self.customSoundsDirectory.appendingPathComponent(meta.relativeFilePath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

            let category = SoundCategory(rawValue: meta.categoryRawValue) ?? .custom

            return SoundEffectItem(
                id: meta.id,
                title: meta.title,
                category: category,
                durationString: meta.durationString,
                frequencyHz: meta.frequencyHz,
                color: .dashYellow,
                relativeFilePath: meta.relativeFilePath,
                isCustom: true,
                waveformSamples: meta.waveformSamples,
                normalizationGain: meta.normalizationGain
            )
        }
    }
}
