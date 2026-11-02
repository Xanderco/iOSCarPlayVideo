import SwiftUI

public struct SoundsHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var soundPlayer = SoundPlayerEngine.shared

    @State private var connectionSoundId: String = "sport_startup"
    @State private var disconnectionSoundId: String = "airline_dingy"
    @State private var homeArrivalSoundId: String = "welcome_traveler"
    @State private var showingShortcutsGuide: Bool = false
    @State private var showingSoundPickerForSlot: String? = nil

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
            .navigationTitle("Sounds")
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
                                    Text("PRO")
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
                title: "Disconnection Sound",
                subtitle: "Plays when CarPlay disconnects",
                currentSoundId: disconnectionSoundId,
                slotKey: "disconnection"
            )

            // Home Arrival Sound Card
            triggerCard(
                icon: "house.fill",
                iconColor: Color.dashAmber,
                title: "Home Arrival Sound",
                subtitle: "Plays when you arrive home",
                currentSoundId: homeArrivalSoundId,
                slotKey: "arrival"
            )
        }
        .padding(.horizontal, 16)
    }

    private func triggerCard(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
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
                    Text("Selected: \(sound.title)")
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
            Text("Top trending")
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
                        Button("Set as Connection Sound") {
                            connectionSoundId = sound.id
                            savePreferences()
                        }
                        Button("Set as Disconnection Sound") {
                            disconnectionSoundId = sound.id
                            savePreferences()
                        }
                        Button("Set as Arrival Sound") {
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

                    Text("\(sound.category.rawValue) · \(sound.durationString)")
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
                    Text("How to Activate?")
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

    // MARK: - Sound Picker Sheet

    private func soundPickerSheet(for slot: String) -> some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(catalog.sounds) { sound in
                            Button {
                                if slot == "disconnection" {
                                    disconnectionSoundId = sound.id
                                } else {
                                    homeArrivalSoundId = sound.id
                                }
                                savePreferences()
                                showingSoundPickerForSlot = nil
                            } label: {
                                HStack(spacing: 12) {
                                    Button {
                                        soundPlayer.play(sound: sound)
                                    } label: {
                                        Image(systemName: soundPlayer.currentlyPlayingId == sound.id ? "stop.fill" : "play.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.dashYellow)
                                            .frame(width: 32, height: 32)
                                            .background(Color.dashYellow.opacity(0.15))
                                            .clipShape(Circle())
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sound.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.dashTextPrimary)

                                        Text("\(sound.category.rawValue) · \(sound.durationString)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }

                                    Spacer()

                                    let isSelected = (slot == "disconnection" ? disconnectionSoundId : homeArrivalSoundId) == sound.id
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected ? Color.dashYellow : Color.dashTextMuted)
                                }
                                .padding(12)
                                .background(Color.dashSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Select Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingSoundPickerForSlot = nil
                    }
                    .foregroundStyle(Color.dashYellow)
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
