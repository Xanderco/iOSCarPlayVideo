import Foundation

/// Families of synthesized car chimes. Every chime is generated on device from a short
/// note sequence. No recorded or licensed audio ships with the app.
public enum SoundCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case bells = "Bells"
    case tones = "Tones"
    case signals = "Signals"

    public var id: String { rawValue }

    /// Categories shown as sections in the picker (excludes `.all`).
    public static var pickable: [SoundCategory] { allCases.filter { $0 != .all } }
}

public struct SoundEffectItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let category: SoundCategory
    /// Note frequencies in Hz, played in sequence.
    public let notes: [Double]

    public init(id: String, title: String, category: SoundCategory, notes: [Double]) {
        self.id = id
        self.title = title
        self.category = category
        self.notes = notes.isEmpty ? [440] : notes
    }

    /// First note, kept for callers that need a single representative pitch.
    public var frequencyHz: Double { notes.first ?? 440 }

    /// Approximate playback length in seconds.
    public var duration: Double { Double(notes.count) * SoundEffectItem.noteLength + 0.4 }

    public static let noteLength: Double = 0.28
}

public final class SoundCatalogService {
    public static let shared = SoundCatalogService()

    public static let defaultSoundId = "harbor_bell"

    public let sounds: [SoundEffectItem] = [
        // Bells: soft, two or three notes
        SoundEffectItem(id: "harbor_bell", title: "Harbor Bell", category: .bells, notes: [659.25, 987.77]),
        SoundEffectItem(id: "glass_bell", title: "Glass Bell", category: .bells, notes: [1046.5, 1318.5]),
        SoundEffectItem(id: "evening_bell", title: "Evening Bell", category: .bells, notes: [523.25, 392.0]),
        SoundEffectItem(id: "porch_bell", title: "Porch Bell", category: .bells, notes: [783.99, 659.25, 783.99]),

        // Tones: calm, single or rising
        SoundEffectItem(id: "soft_hello", title: "Soft Hello", category: .tones, notes: [440.0, 554.37]),
        SoundEffectItem(id: "warm_start", title: "Warm Start", category: .tones, notes: [261.63, 329.63, 392.0]),
        SoundEffectItem(id: "low_hum", title: "Low Hum", category: .tones, notes: [196.0]),
        SoundEffectItem(id: "night_mode", title: "Night Mode", category: .tones, notes: [349.23, 293.66]),
        SoundEffectItem(id: "sunrise", title: "Sunrise", category: .tones, notes: [293.66, 369.99, 440.0, 587.33]),

        // Signals: short and bright
        SoundEffectItem(id: "quick_ping", title: "Quick Ping", category: .signals, notes: [1567.98]),
        SoundEffectItem(id: "double_tap", title: "Double Tap", category: .signals, notes: [880.0, 880.0]),
        SoundEffectItem(id: "ready_rise", title: "Ready Rise", category: .signals, notes: [587.33, 880.0, 1174.66]),
        SoundEffectItem(id: "studio_click", title: "Studio Click", category: .signals, notes: [2093.0, 1567.98])
    ]

    public func sounds(for category: SoundCategory) -> [SoundEffectItem] {
        if category == .all {
            return sounds
        }
        return sounds.filter { $0.category == category }
    }

    public func sound(withId id: String?) -> SoundEffectItem? {
        guard let id else { return nil }
        return sounds.first { $0.id == id }
    }

    /// The chime the user picked, falling back to the default when unset or unknown.
    public func selectedSound(preferences: UserPreferences = PersistenceController.shared.loadUserPreferences()) -> SoundEffectItem {
        sound(withId: preferences.connectionSoundId)
            ?? sound(withId: SoundCatalogService.defaultSoundId)
            ?? sounds[0]
    }
}
