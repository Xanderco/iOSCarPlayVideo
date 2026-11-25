import Foundation
import AVFoundation

/// Kind of selectable media track exposed by `VideoPlayerService`.
public enum MediaTrackKind: String, Sendable, Equatable, CaseIterable {
    case audio
    case subtitle
}

/// Platform-neutral, testable representation of a selectable audio or subtitle track.
public struct MediaTrackOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let languageCode: String?
    public let isForcedSubtitle: Bool
    public let isSDH: Bool
    public let isDefault: Bool
    /// Index into `AVMediaSelectionGroup.options`, or `nil` for the synthetic "Off" subtitle option.
    public let optionIndex: Int?

    public var isOff: Bool { optionIndex == nil }

    public init(
        id: String,
        displayName: String,
        languageCode: String?,
        isForcedSubtitle: Bool = false,
        isSDH: Bool = false,
        isDefault: Bool = false,
        optionIndex: Int?
    ) {
        self.id = id
        self.displayName = displayName
        self.languageCode = languageCode
        self.isForcedSubtitle = isForcedSubtitle
        self.isSDH = isSDH
        self.isDefault = isDefault
        self.optionIndex = optionIndex
    }

    public static let subtitlesOff = MediaTrackOption(
        id: "__off__",
        displayName: "Off",
        languageCode: nil,
        isForcedSubtitle: false,
        isSDH: false,
        isDefault: false,
        optionIndex: nil
    )
}

/// Pure policy & `UserDefaults` persistence for audio/subtitle track filtering and language auto-matching.
public final class MediaTrackSelectionPolicy {
    public static let shared = MediaTrackSelectionPolicy()

    public static let preferredAudioLanguageKey = "dashcast.player.preferredAudioLanguage"
    public static let preferredSubtitleLanguageKey = "dashcast.player.preferredSubtitleLanguage"
    public static let subtitlesExplicitlyOffKey = "dashcast.player.subtitlesExplicitlyOff"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Persisted Preferences

    public var preferredAudioLanguageCode: String? {
        get { Self.normalizedLanguageCode(defaults.string(forKey: Self.preferredAudioLanguageKey)) }
        set {
            if let normalized = Self.normalizedLanguageCode(newValue) {
                defaults.set(normalized, forKey: Self.preferredAudioLanguageKey)
            } else {
                defaults.removeObject(forKey: Self.preferredAudioLanguageKey)
            }
        }
    }

    public var preferredSubtitleLanguageCode: String? {
        get {
            guard !areSubtitlesExplicitlyOff else { return nil }
            return Self.normalizedLanguageCode(defaults.string(forKey: Self.preferredSubtitleLanguageKey))
        }
        set {
            if let normalized = Self.normalizedLanguageCode(newValue) {
                defaults.set(false, forKey: Self.subtitlesExplicitlyOffKey)
                defaults.set(normalized, forKey: Self.preferredSubtitleLanguageKey)
            } else {
                defaults.removeObject(forKey: Self.preferredSubtitleLanguageKey)
            }
        }
    }

    public var areSubtitlesExplicitlyOff: Bool {
        get { defaults.bool(forKey: Self.subtitlesExplicitlyOffKey) }
        set { defaults.set(newValue, forKey: Self.subtitlesExplicitlyOffKey) }
    }

    public var hasSavedPreferences: Bool {
        preferredAudioLanguageCode != nil || preferredSubtitleLanguageCode != nil || areSubtitlesExplicitlyOff
    }

    public func recordAudioSelection(_ option: MediaTrackOption) {
        preferredAudioLanguageCode = option.languageCode
    }

    public func recordSubtitleSelection(_ option: MediaTrackOption?) {
        guard let option, !option.isOff else {
            areSubtitlesExplicitlyOff = true
            defaults.removeObject(forKey: Self.preferredSubtitleLanguageKey)
            return
        }
        areSubtitlesExplicitlyOff = false
        preferredSubtitleLanguageCode = option.languageCode
    }

    public func clearPreferences() {
        defaults.removeObject(forKey: Self.preferredAudioLanguageKey)
        defaults.removeObject(forKey: Self.preferredSubtitleLanguageKey)
        defaults.removeObject(forKey: Self.subtitlesExplicitlyOffKey)
    }

    // MARK: - Filtering & Matching

    /// Normalizes a BCP-47 / ISO-639 language identifier (`"es-419"`, `"EN_US"`, etc.).
    public static func normalizedLanguageCode(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Extracts the primary language subtag (`"es-mx"` -> `"es"`).
    public static func baseLanguageCode(_ raw: String?) -> String? {
        guard let normalized = normalizedLanguageCode(raw) else { return nil }
        if let hyphen = normalized.firstIndex(of: "-") {
            let prefix = String(normalized[..<hyphen])
            return prefix.isEmpty ? normalized : prefix
        }
        return normalized
    }

    /// Filters raw track options for presentation in the track picker.
    /// - Removes forced-only subtitle tracks by default (AVPlayer shows forced subtitles automatically when `nil` is selected).
    /// - Removes synthetic `"off"` entries and deduplicates identical `(languageCode, displayName, isSDH)` entries.
    public static func filterOptions(
        _ options: [MediaTrackOption],
        kind: MediaTrackKind,
        includeForcedSubtitles: Bool = false
    ) -> [MediaTrackOption] {
        var seen = Set<String>()
        var result: [MediaTrackOption] = []

        for option in options {
            guard !option.isOff else { continue }
            if kind == .subtitle && option.isForcedSubtitle && !includeForcedSubtitles {
                continue
            }
            let normalizedLang = normalizedLanguageCode(option.languageCode) ?? ""
            let normalizedName = option.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty || !normalizedLang.isEmpty else { continue }

            let dedupeKey = "\(normalizedLang)|\(normalizedName.lowercased())|\(option.isSDH)|\(option.isForcedSubtitle)"
            if seen.insert(dedupeKey).inserted {
                result.append(option)
            }
        }
        return result
    }

    /// Finds the best matching option for a preferred language code:
    /// 1. Exact case-insensitive BCP-47 match (`"es-419"` == `"es-419"`).
    /// 2. Base language subtag match (`"es-419"` matches `"es"` or `"es-es"`), preferring non-SDH when tied.
    public static func matchOption(
        forLanguageCode preferredCode: String?,
        in options: [MediaTrackOption]
    ) -> MediaTrackOption? {
        guard let target = normalizedLanguageCode(preferredCode), !options.isEmpty else {
            return nil
        }

        // Pass 1: exact normalized tag match
        if let exact = options.first(where: { normalizedLanguageCode($0.languageCode) == target }) {
            return exact
        }

        // Pass 2: base language code match (e.g. "es-MX" -> "es")
        guard let targetBase = baseLanguageCode(target) else { return nil }
        let baseMatches = options.filter { baseLanguageCode($0.languageCode) == targetBase }
        if let nonSDH = baseMatches.first(where: { !$0.isSDH }) {
            return nonSDH
        }
        return baseMatches.first
    }

    /// Resolves which audio track should be auto-selected for a newly loaded item.
    /// Returns `nil` when no preference is saved or no candidate matches, leaving AVPlayer's default intact.
    public func resolveAutoAudioOption(from availableOptions: [MediaTrackOption]) -> MediaTrackOption? {
        let filtered = Self.filterOptions(availableOptions, kind: .audio)
        return Self.matchOption(forLanguageCode: preferredAudioLanguageCode, in: filtered)
    }

    /// Resolves which subtitle track should be auto-selected for a newly loaded item.
    /// Returns `nil` when subtitles are explicitly Off or no saved preference matches.
    public func resolveAutoSubtitleOption(from availableOptions: [MediaTrackOption]) -> MediaTrackOption? {
        guard !areSubtitlesExplicitlyOff else { return nil }
        let filtered = Self.filterOptions(availableOptions, kind: .subtitle)
        return Self.matchOption(forLanguageCode: preferredSubtitleLanguageCode, in: filtered)
    }

    // MARK: - AVFoundation Extraction

    /// Converts an `AVMediaSelectionGroup` into filtered, deterministic `MediaTrackOption` values.
    public static func buildOptions(
        from group: AVMediaSelectionGroup?,
        kind: MediaTrackKind,
        displayLocale: Locale = .current,
        includeForcedSubtitles: Bool = false
    ) -> [MediaTrackOption] {
        guard let group else { return [] }
        let playableSet = Set(AVMediaSelectionGroup.playableMediaSelectionOptions(from: group.options))
        var rawOptions: [MediaTrackOption] = []

        for (index, option) in group.options.enumerated() {
            guard playableSet.contains(option) else { continue }
            let rawCode = option.extendedLanguageTag ?? option.locale?.identifier
            let normalizedCode = normalizedLanguageCode(rawCode)
            let isForced = option.hasMediaCharacteristic(.containsOnlyForcedSubtitles)
            let isSDH = option.hasMediaCharacteristic(.describesMusicAndSoundForAccessibility)
                || option.hasMediaCharacteristic(.transcribesSpokenDialogForAccessibility)
            let isDefault = option.hasMediaCharacteristic(.isMainProgramContent)

            let resolvedName = resolvedDisplayName(
                for: option,
                languageCode: normalizedCode,
                index: index,
                displayLocale: displayLocale
            )

            let id = "\(kind.rawValue)-\(index)-\(normalizedCode ?? "und")-\(isSDH ? "sdh" : "std")"
            rawOptions.append(
                MediaTrackOption(
                    id: id,
                    displayName: resolvedName,
                    languageCode: normalizedCode,
                    isForcedSubtitle: isForced,
                    isSDH: isSDH,
                    isDefault: isDefault,
                    optionIndex: index
                )
            )
        }

        return filterOptions(rawOptions, kind: kind, includeForcedSubtitles: includeForcedSubtitles)
    }

    private static func resolvedDisplayName(
        for option: AVMediaSelectionOption,
        languageCode: String?,
        index: Int,
        displayLocale: Locale
    ) -> String {
        let avName = option.displayName(with: displayLocale).trimmingCharacters(in: .whitespacesAndNewlines)
        if !avName.isEmpty {
            return avName
        }
        if let languageCode,
           let localized = displayLocale.localizedString(forIdentifier: languageCode),
           !localized.isEmpty {
            return localized
        }
        if let languageCode {
            return languageCode.uppercased()
        }
        return "Track \(index + 1)"
    }
}
