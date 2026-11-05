import Foundation
import SwiftUI

public enum SoundCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case voices = "Voices"
    case engine = "Engine"
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

    public init(id: String, title: String, category: SoundCategory, durationString: String = "0:02", frequencyHz: Double = 440, color: Color = .dcSuccess) {
        self.id = id
        self.title = title
        self.category = category
        self.durationString = durationString
        self.frequencyHz = frequencyHz
        self.color = color
    }
}

public final class SoundCatalogService {
    public static let shared = SoundCatalogService()

    public let sounds: [SoundEffectItem] = [
        // Connection & Futuristic
        SoundEffectItem(id: "jet_startup", title: "Jet Startup", category: .futuristic, durationString: "0:03", frequencyHz: 520, color: .dcAccent),
        SoundEffectItem(id: "hyperspace", title: "Hyperspace Jump", category: .futuristic, durationString: "0:02", frequencyHz: 680, color: .dcAccent),
        SoundEffectItem(id: "electric_warp", title: "Electric Warp Pulse", category: .futuristic, durationString: "0:02", frequencyHz: 840, color: .dcWarning),

        // Disconnection & Chimes
        SoundEffectItem(id: "airline_dingy", title: "Airline Dingy", category: .chimes, durationString: "0:02", frequencyHz: 600, color: .dcWarning),
        SoundEffectItem(id: "luxury_chime", title: "Luxury Sedan Chime", category: .chimes, durationString: "0:03", frequencyHz: 750, color: .dcPro),
        SoundEffectItem(id: "crystal_ping", title: "Crystal Ping", category: .chimes, durationString: "0:01", frequencyHz: 920, color: .dcSuccess),

        // Voices
        SoundEffectItem(id: "welcome_sir", title: "Welcome Back Sir", category: .voices, durationString: "0:02", frequencyHz: 350, color: .dcPro),
        SoundEffectItem(id: "welcome_traveler", title: "Welcome Traveler", category: .voices, durationString: "0:01", frequencyHz: 420, color: .dcSuccess),
        SoundEffectItem(id: "ready_for_launch", title: "Ready for Launch", category: .voices, durationString: "0:02", frequencyHz: 480, color: .dcAccent),
        SoundEffectItem(id: "captain_aboard", title: "Good Morning Captain", category: .voices, durationString: "0:02", frequencyHz: 400, color: .dcWarning),

        // Engine
        SoundEffectItem(id: "sport_startup", title: "Sport Car Startup - 1", category: .engine, durationString: "0:05", frequencyHz: 280, color: .dcDanger),
        SoundEffectItem(id: "v8_supercharged", title: "V8 Supercharged Idle", category: .engine, durationString: "0:04", frequencyHz: 220, color: .dcWarning),
        SoundEffectItem(id: "turbo_spool", title: "Twin Turbo Spool", category: .engine, durationString: "0:03", frequencyHz: 550, color: .dcAccent),
        SoundEffectItem(id: "v12_rev", title: "V12 Screamer Rev", category: .engine, durationString: "0:04", frequencyHz: 650, color: .dcDanger),

        // Cinematic
        SoundEffectItem(id: "piano_elegance", title: "Piano Cinematic", category: .cinematic, durationString: "0:04", frequencyHz: 523, color: .dcPro),
        SoundEffectItem(id: "deep_bass_drop", title: "Deep Bass Drop", category: .cinematic, durationString: "0:03", frequencyHz: 180, color: .dcWarning),
        SoundEffectItem(id: "orchestral_fanfare", title: "Orchestral Fanfare", category: .cinematic, durationString: "0:03", frequencyHz: 600, color: .dcSuccess)
    ]

    public func sounds(for category: SoundCategory) -> [SoundEffectItem] {
        if category == .all {
            return sounds
        }
        return sounds.filter { $0.category == category }
    }
}
