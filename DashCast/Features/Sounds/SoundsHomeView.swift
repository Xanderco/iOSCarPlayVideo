import SwiftUI

public struct SoundsHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var soundPlayer = SoundPlayerEngine.shared

    @State private var selectedCategory: SoundCategory = .all
    @State private var connectionSoundId: String = "jet_startup"
    @State private var disconnectionSoundId: String = "airline_dingy"
    @State private var homeArrivalSoundId: String = "welcome_sir"
    @State private var showingShortcutsGuide: Bool = false

    private let catalog = SoundCatalogService.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        // Top Active Trigger Slots (Connection, Disconnection, Arrival)
                        activeTriggerSlots

                        // Category Pills
                        categoryPills

                        // Soundboard Grid
                        soundboardGrid

                        // Siri Waveform & Shortcuts Guide CTA
                        waveformCTASection
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Car Sounds")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingShortcutsGuide = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.dashCyan)
                    }
                }
            }
            .sheet(isPresented: $showingShortcutsGuide) {
                ShortcutsGuideView()
            }
            .onAppear {
                let prefs = loadPreferences()
                if let conn = prefs.connectionSoundId { connectionSoundId = conn }
                if let disc = prefs.disconnectionSoundId { disconnectionSoundId = disc }
                if let home = prefs.homeArrivalSoundId { homeArrivalSoundId = home }
            }
        }
    }

    private var activeTriggerSlots: some View {
        VStack(spacing: 12) {
            triggerSlotCard(
                slotTitle: "Connection Sound",
                soundId: connectionSoundId,
                icon: "bolt.fill",
                accentColor: .dashGreen
            ) {
                assignSound(type: .connection, id: $0)
            }

            triggerSlotCard(
                slotTitle: "Disconnection Sound",
                soundId: disconnectionSoundId,
                icon: "power",
                accentColor: .dashRed
            ) {
                assignSound(type: .disconnection, id: $0)
            }

            triggerSlotCard(
                slotTitle: "Home Arrival Sound",
                soundId: homeArrivalSoundId,
                icon: "house.fill",
                accentColor: .dashGold
            ) {
                assignSound(type: .arrival, id: $0)
            }
        }
        .padding(.horizontal)
    }

    private func triggerSlotCard(
        slotTitle: String,
        soundId: String,
        icon: String,
        accentColor: Color,
        onAssign: @escaping (String) -> Void
    ) -> some View {
        let sound = catalog.sounds.first(where: { $0.id == soundId })
        let isPlaying = soundPlayer.currentlyPlayingId == soundId

        return AutomotiveCard(cornerRadius: 16) {
            HStack(spacing: 14) {
                Button {
                    if let sound {
                        soundPlayer.play(sound: sound)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(slotTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dashCyan)
                        Text(sound?.title ?? "None Selected")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dashCyan)
                    }
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.dashBlue)
            }
        }
    }

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SoundCategory.allCases) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        Text(cat.rawValue)
                            .font(.system(size: 14, weight: selectedCategory == cat ? .bold : .medium))
                            .foregroundStyle(selectedCategory == cat ? Color.black : Color.dashTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == cat
                                ? AnyView(LinearGradient.dashAccentGradient)
                                : AnyView(Color.dashSurface)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var soundboardGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(catalog.sounds(for: selectedCategory)) { sound in
                let isPlaying = soundPlayer.currentlyPlayingId == sound.id
                AutomotiveCard(cornerRadius: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button {
                                soundPlayer.play(sound: sound)
                            } label: {
                                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(sound.color)
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
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.dashTextMuted)
                            }
                        }

                        Text(sound.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                            .lineLimit(1)

                        HStack {
                            Text(sound.category.rawValue)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dashTextMuted)
                            Spacer()
                            Text(sound.durationString)
                                .font(ThemeFonts.monospaceDigits(size: 11))
                                .foregroundStyle(Color.dashTextMuted)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var waveformCTASection: some View {
        VStack(spacing: 12) {
            // Siri Waveform visualization
            HStack(spacing: 4) {
                ForEach(0..<18, id: \.self) { i in
                    let height: CGFloat = CGFloat(12 + (sin(Double(i) * 0.6) * 14))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.dashCyan, .dashGreen],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: max(6, height))
                }
            }
            .frame(height: 36)

            Button {
                showingShortcutsGuide = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.dashCyan)
                    Text("Follow in-app setup guide to configure automations")
                        .font(ThemeFonts.hudCaption(size: 13))
                        .foregroundStyle(Color.dashCyan)
                        .underline()
                }
            }
        }
        .padding(.top, 8)
    }

    private enum SlotType {
        case connection, disconnection, arrival
    }

    private func assignSound(type: SlotType, id: String) {
        switch type {
        case .connection: connectionSoundId = id
        case .disconnection: disconnectionSoundId = id
        case .arrival: homeArrivalSoundId = id
        }
        savePreferences()
    }

    private func savePreferences() {
        var prefs = loadPreferences()
        prefs.connectionSoundId = connectionSoundId
        prefs.disconnectionSoundId = disconnectionSoundId
        prefs.homeArrivalSoundId = homeArrivalSoundId
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: "dashcast_user_prefs")
        }
    }

    private func loadPreferences() -> UserPreferences {
        if let data = UserDefaults.standard.data(forKey: "dashcast_user_prefs"),
           let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            return prefs
        }
        return UserPreferences()
    }
}
