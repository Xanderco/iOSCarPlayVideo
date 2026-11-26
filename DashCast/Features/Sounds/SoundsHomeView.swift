import SwiftUI

/// Pure filtering and slot-copy resolution helpers for `SoundsHomeView`.
public enum SoundsHomeCatalogFilter {
    nonisolated public static let pickerCategories: [String] = [
        SoundsHomeCopy.recommendCategoryString,
        SoundsHomeCopy.allCategoryString,
        SoundsHomeCopy.brandsCategoryString,
        SoundsHomeCopy.voicesCategoryString,
        SoundsHomeCopy.engineCategoryString,
        SoundsHomeCopy.futuristicCategoryString
    ]

    nonisolated public static func filter(
        sounds: [SoundEffectItem],
        category: String,
        searchText: String
    ) -> [SoundEffectItem] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let includeAllCategories = (category == SoundsHomeCopy.allCategoryString || category == SoundsHomeCopy.recommendCategoryString)

        return sounds.filter { sound in
            let matchesCategory = includeAllCategories
                || sound.category.rawValue.localizedCaseInsensitiveContains(category)
            let matchesSearch = trimmedQuery.isEmpty
                || sound.title.localizedCaseInsensitiveContains(trimmedQuery)
            return matchesCategory && matchesSearch
        }
    }

    nonisolated public static func sheetTitleString(for slotKey: String) -> String {
        slotKey == "disconnection"
            ? SoundsHomeCopy.selectDisconnectionSoundString
            : SoundsHomeCopy.selectConnectionSoundString
    }

    nonisolated public static func setActionTitleString(for slotKey: String) -> String {
        switch slotKey {
        case "disconnection":
            return SoundsHomeCopy.setAsDisconnectionSoundString
        case "arrival":
            return SoundsHomeCopy.setAsArrivalSoundString
        default:
            return SoundsHomeCopy.setAsConnectionSoundString
        }
    }

    @MainActor
    public static func sheetTitleKey(for slotKey: String) -> LocalizedStringKey {
        LocalizedStringKey(sheetTitleString(for: slotKey))
    }

    @MainActor
    public static func setActionTitleKey(for slotKey: String) -> LocalizedStringKey {
        LocalizedStringKey(setActionTitleString(for: slotKey))
    }
}

/// Localized copy keys and formatting helpers for `SoundsHomeView`.
public enum SoundsHomeCopy {
    nonisolated public static let soundsTitleString = "Sounds"
    nonisolated public static let proBadgeString = "PRO"
    nonisolated public static let disconnectionSoundString = "Disconnection Sound"
    nonisolated public static let disconnectionSubtitleString = "Plays when CarPlay disconnects"
    nonisolated public static let homeArrivalSoundString = "Home Arrival Sound"
    nonisolated public static let homeArrivalSubtitleString = "Plays when you arrive home"
    nonisolated public static let selectedSoundFormatString = "Selected: %@"
    nonisolated public static let topTrendingString = "Top trending"
    nonisolated public static let setAsConnectionSoundString = "Set as Connection Sound"
    nonisolated public static let setAsDisconnectionSoundString = "Set as Disconnection Sound"
    nonisolated public static let setAsArrivalSoundString = "Set as Arrival Sound"
    nonisolated public static let howToActivateString = "How to Activate?"
    nonisolated public static let selectDisconnectionSoundString = "Select Disconnection Sound"
    nonisolated public static let selectConnectionSoundString = "Select Connection Sound"
    nonisolated public static let recommendCategoryString = "Recommend"
    nonisolated public static let allCategoryString = "All"
    nonisolated public static let brandsCategoryString = "Brands"
    nonisolated public static let voicesCategoryString = "Voices"
    nonisolated public static let engineCategoryString = "Engine"
    nonisolated public static let futuristicCategoryString = "Futuristic"
    nonisolated public static let chimesCategoryString = "Chimes"
    nonisolated public static let cinematicCategoryString = "Cinematic"
    nonisolated public static let searchSoundPlaceholderString = "Search a sound"
    nonisolated public static let previewGuidanceString = "Tap ▶ to preview, tap the card to select"
    nonisolated public static let selectASoundString = "Select a sound"

    nonisolated public static let allLocalizationKeys: [String] = [
        soundsTitleString,
        proBadgeString,
        disconnectionSoundString,
        disconnectionSubtitleString,
        homeArrivalSoundString,
        homeArrivalSubtitleString,
        selectedSoundFormatString,
        topTrendingString,
        setAsConnectionSoundString,
        setAsDisconnectionSoundString,
        setAsArrivalSoundString,
        howToActivateString,
        selectDisconnectionSoundString,
        selectConnectionSoundString,
        recommendCategoryString,
        allCategoryString,
        brandsCategoryString,
        voicesCategoryString,
        engineCategoryString,
        futuristicCategoryString,
        chimesCategoryString,
        cinematicCategoryString,
        searchSoundPlaceholderString,
        previewGuidanceString,
        selectASoundString
    ]

    @MainActor public static var soundsTitleKey: LocalizedStringKey { LocalizedStringKey(soundsTitleString) }
    @MainActor public static var proBadgeKey: LocalizedStringKey { LocalizedStringKey(proBadgeString) }
    @MainActor public static var disconnectionSoundKey: LocalizedStringKey { LocalizedStringKey(disconnectionSoundString) }
    @MainActor public static var disconnectionSubtitleKey: LocalizedStringKey { LocalizedStringKey(disconnectionSubtitleString) }
    @MainActor public static var homeArrivalSoundKey: LocalizedStringKey { LocalizedStringKey(homeArrivalSoundString) }
    @MainActor public static var homeArrivalSubtitleKey: LocalizedStringKey { LocalizedStringKey(homeArrivalSubtitleString) }
    @MainActor public static var topTrendingKey: LocalizedStringKey { LocalizedStringKey(topTrendingString) }
    @MainActor public static var howToActivateKey: LocalizedStringKey { LocalizedStringKey(howToActivateString) }
    @MainActor public static var searchSoundPlaceholderKey: LocalizedStringKey { LocalizedStringKey(searchSoundPlaceholderString) }
    @MainActor public static var previewGuidanceKey: LocalizedStringKey { LocalizedStringKey(previewGuidanceString) }
    @MainActor public static var selectASoundKey: LocalizedStringKey { LocalizedStringKey(selectASoundString) }

    @MainActor
    public static func selectedSoundKey(_ title: String) -> LocalizedStringKey {
        LocalizedStringKey("Selected: \(title)")
    }

    nonisolated public static func categoryDurationText(
        category: SoundCategory,
        duration: String,
        bundle: Bundle = .main
    ) -> String {
        let localizedCategory = String(localized: String.LocalizationValue(category.rawValue), bundle: bundle)
        return "\(localizedCategory) · \(duration)"
    }
}

public struct SoundsHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var soundPlayer = SoundPlayerEngine.shared

    @State private var connectionSoundId: String = "sport_startup"
    @State private var disconnectionSoundId: String = "airline_dingy"
    @State private var homeArrivalSoundId: String = "welcome_traveler"
    @State private var showingShortcutsGuide: Bool = false
    @State private var showingSoundPickerForSlot: String? = nil
    @State private var soundSearchText: String = ""
    @State private var pickerCategory: String = SoundsHomeCopy.recommendCategoryString

    private let catalog = SoundCatalogService.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Top Sound Triggers (Disconnection, Home Arrival)
                        topTriggerCards

                        // Section: Top trending
                        topTrendingSection

                        // Spacer for bottom sticky button and capsule bar
                        Color.clear.frame(height: 120)
                    }
                    .padding(.top, 10)
                }

                // Sticky "How to Activate? 🪄" Button above the tab bar
                howToActivateStickyButton
            }
            .navigationTitle(SoundsHomeCopy.soundsTitleKey)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        if !appState.isProLifetimeUnlocked {
                            Button {
                                appState.showPaywall = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11))
                                    Text(SoundsHomeCopy.proBadgeKey)
                                        .font(.system(size: 12, weight: .heavy))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(LinearGradient.dashProGoldGradient)
                                .foregroundStyle(Color.black)
                                .clipShape(Capsule())
                            }
                        }

                        Button {
                            showingShortcutsGuide = true
                        } label: {
                            Image(systemName: "questionmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.dashTextPrimary)
                                .frame(width: 32, height: 32)
                                .background(Color.dashSurface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.dashBorder, lineWidth: 1))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShortcutsGuide) {
                ShortcutsGuideView()
            }
            .sheet(item: Binding(
                get: { showingSoundPickerForSlot.map { SoundSlotIdentifiable(id: $0) } },
                set: { showingSoundPickerForSlot = $0?.id }
            )) { slot in
                soundPickerSheet(for: slot.id)
            }
            .onAppear {
                loadPreferences()
            }
        }
    }

    // MARK: - Top Trigger Cards

    private var topTriggerCards: some View {
        VStack(spacing: 12) {
            // Disconnection Sound Card
            triggerCard(
                icon: "stop.circle.fill",
                iconColor: Color(red: 0.85, green: 0.25, blue: 0.25),
                title: SoundsHomeCopy.disconnectionSoundKey,
                subtitle: SoundsHomeCopy.disconnectionSubtitleKey,
                currentSoundId: disconnectionSoundId,
                slotKey: "disconnection"
            )

            // Home Arrival Sound Card
            triggerCard(
                icon: "house.fill",
                iconColor: Color.dashAmber,
                title: SoundsHomeCopy.homeArrivalSoundKey,
                subtitle: SoundsHomeCopy.homeArrivalSubtitleKey,
                currentSoundId: homeArrivalSoundId,
                slotKey: "arrival"
            )
        }
        .padding(.horizontal, 16)
    }

    private func triggerCard(
        icon: String,
        iconColor: Color,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        currentSoundId: String,
        slotKey: String
    ) -> some View {
        let sound = catalog.sounds.first(where: { $0.id == currentSoundId })
        let isPlaying = soundPlayer.currentlyPlayingId == currentSoundId

        return HStack(spacing: 14) {
            Button {
                if let sound {
                    soundPlayer.play(sound: sound)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.25))
                        .frame(width: 46, height: 46)

                    Image(systemName: isPlaying ? "stop.fill" : (slotKey == "arrival" ? "house.fill" : "play.fill"))
                        .font(.system(size: 20))
                        .foregroundStyle(iconColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dashTextPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dashTextSecondary)

                if let sound {
                    Text(SoundsHomeCopy.selectedSoundKey(sound.title))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.dashYellow)
                }
            }

            Spacer()

            Button {
                showingSoundPickerForSlot = slotKey
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.dashYellow)
                    .frame(width: 32, height: 32)
                    .background(Color.dashSurfaceHighlight)
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    // MARK: - Top Trending Section

    private var topTrendingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(SoundsHomeCopy.topTrendingKey)
                .font(ThemeFonts.hudTitle(size: 18))
                .foregroundStyle(Color.dashTextPrimary)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(catalog.sounds) { sound in
                    trendingSoundTile(sound: sound)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func trendingSoundTile(sound: SoundEffectItem) -> some View {
        let isPlaying = soundPlayer.currentlyPlayingId == sound.id

        return ZStack(alignment: .topTrailing) {
            // Background gradient card
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tileGradient(for: sound))
                .frame(height: 125)

            // Watermark icon
            Image(systemName: watermarkIcon(for: sound))
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.12))
                .offset(x: -8, y: 12)

            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button {
                        soundPlayer.play(sound: sound)
                    } label: {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.white)
                    }

                    Spacer()

                    Menu {
                        Button(SoundsHomeCatalogFilter.setActionTitleKey(for: "connection")) {
                            connectionSoundId = sound.id
                            savePreferences()
                        }
                        Button(SoundsHomeCatalogFilter.setActionTitleKey(for: "disconnection")) {
                            disconnectionSoundId = sound.id
                            savePreferences()
                        }
                        Button(SoundsHomeCatalogFilter.setActionTitleKey(for: "arrival")) {
                            homeArrivalSoundId = sound.id
                            savePreferences()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    Text(SoundsHomeCopy.categoryDurationText(category: sound.category, duration: sound.durationString))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .padding(12)
        }
    }

    // MARK: - Sticky "How to Activate? 🪄" Button

    private var howToActivateStickyButton: some View {
        VStack(spacing: 0) {
            Button {
                showingShortcutsGuide = true
            } label: {
                HStack(spacing: 8) {
                    Text(SoundsHomeCopy.howToActivateKey)
                        .font(.system(size: 16, weight: .bold))
                    Text("🪄")
                        .font(.system(size: 16))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(LinearGradient.dashAccentGradient)
                .clipShape(Capsule())
                .shadow(color: Color.dashYellow.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 75) // sits above the liquid tab bar
        }
    }

    // MARK: - Sound Picker Sheet (Matching Select CarPlay Connection Sound.jpeg)

    private func soundPickerSheet(for slot: String) -> some View {
        let titleKey = SoundsHomeCatalogFilter.sheetTitleKey(for: slot)
        let categories = SoundsHomeCatalogFilter.pickerCategories

        return NavigationStack {
            ZStack(alignment: .bottom) {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.dashTextMuted)
                        TextField(SoundsHomeCopy.searchSoundPlaceholderKey, text: $soundSearchText)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.dashTextPrimary)
                    }
                    .padding(12)
                    .background(Color.dashSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Category Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                Button {
                                    pickerCategory = cat
                                } label: {
                                    Text(LocalizedStringKey(cat))
                                        .font(.system(size: 13, weight: pickerCategory == cat ? .bold : .medium))
                                        .foregroundStyle(pickerCategory == cat ? Color.black : Color.dashTextSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            pickerCategory == cat
                                            ? AnyView(LinearGradient.dashAccentGradient)
                                            : AnyView(Color.dashSurface)
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Guidance caption
                    Text(SoundsHomeCopy.previewGuidanceKey)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.dashTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)

                    // Sound List
                    ScrollView {
                        VStack(spacing: 10) {
                            let list = SoundsHomeCatalogFilter.filter(
                                sounds: catalog.sounds,
                                category: pickerCategory,
                                searchText: soundSearchText
                            )

                            ForEach(list) { sound in
                                Button {
                                    if slot == "disconnection" {
                                        disconnectionSoundId = sound.id
                                    } else {
                                        homeArrivalSoundId = sound.id
                                    }
                                    savePreferences()
                                    showingSoundPickerForSlot = nil
                                } label: {
                                    HStack(spacing: 14) {
                                        Button {
                                            soundPlayer.play(sound: sound)
                                        } label: {
                                            Image(systemName: soundPlayer.currentlyPlayingId == sound.id ? "stop.circle.fill" : "play.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundStyle(Color.dashYellow)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(sound.title)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(Color.dashTextPrimary)

                                            Text(SoundsHomeCopy.categoryDurationText(category: sound.category, duration: sound.durationString))
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.dashTextSecondary)
                                        }

                                        Spacer()

                                        let isSelected = (slot == "disconnection" ? disconnectionSoundId : homeArrivalSoundId) == sound.id
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(isSelected ? Color.dashYellow : Color.dashTextMuted)
                                    }
                                    .padding(14)
                                    .background(Color.dashSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.dashBorder, lineWidth: 1)
                                    )
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                            }

                            Color.clear.frame(height: 90)
                        }
                        .padding(.top, 4)
                    }
                }

                // Sticky Bottom Select Button
                Button {
                    showingSoundPickerForSlot = nil
                } label: {
                    Text(SoundsHomeCopy.selectASoundKey)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient.dashAccentGradient)
                        .clipShape(Capsule())
                        .shadow(color: Color.dashYellow.opacity(0.35), radius: 10, y: 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationTitle(titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSoundPickerForSlot = nil
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.dashYellow)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func tileGradient(for sound: SoundEffectItem) -> LinearGradient {
        switch sound.category {
        case .engine:
            return LinearGradient(colors: [Color(red: 0.6, green: 0.15, blue: 0.15), Color(red: 0.2, green: 0.05, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .voices:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.45, blue: 0.25), Color(red: 0.05, green: 0.15, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .futuristic:
            return LinearGradient(colors: [Color(red: 0.6, green: 0.45, blue: 0.1), Color(red: 0.18, green: 0.12, blue: 0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .chimes:
            return LinearGradient(colors: [Color(red: 0.15, green: 0.35, blue: 0.6), Color(red: 0.04, green: 0.1, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cinematic:
            return LinearGradient(colors: [Color(red: 0.35, green: 0.15, blue: 0.5), Color(red: 0.1, green: 0.04, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color.dashSurfaceHighlight, Color.dashSurface], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func watermarkIcon(for sound: SoundEffectItem) -> String {
        switch sound.category {
        case .engine: return "key.fill"
        case .voices: return "person.wave.2.fill"
        case .futuristic: return "airplane"
        case .chimes: return "bell.fill"
        case .cinematic: return "film.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    private func loadPreferences() {
        let prefs = PersistenceController.shared.loadUserPreferences()
        if let conn = prefs.connectionSoundId { self.connectionSoundId = conn }
        if let disc = prefs.disconnectionSoundId { self.disconnectionSoundId = disc }
        if let arriv = prefs.homeArrivalSoundId { self.homeArrivalSoundId = arriv }
    }

    private func savePreferences() {
        var prefs = PersistenceController.shared.loadUserPreferences()
        prefs.connectionSoundId = connectionSoundId
        prefs.disconnectionSoundId = disconnectionSoundId
        prefs.homeArrivalSoundId = homeArrivalSoundId
        PersistenceController.shared.saveUserPreferences(prefs)
    }
}

private struct SoundSlotIdentifiable: Identifiable {
    let id: String
}
