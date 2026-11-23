import SwiftUI
import UniformTypeIdentifiers

public struct SoundsHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var soundPlayer = SoundPlayerEngine.shared
    @ObservedObject private var catalog = SoundCatalogService.shared

    @State private var connectionSoundId: String = "sport_startup"
    @State private var disconnectionSoundId: String = "airline_dingy"
    @State private var homeArrivalSoundId: String = "welcome_traveler"
    @State private var showingShortcutsGuide: Bool = false
    @State private var showingSoundPickerForSlot: String? = nil
    @State private var soundSearchText: String = ""
    @State private var pickerCategory: String = "Recommend"
    @State private var showingFileImporter: Bool = false
    @State private var importErrorMessage: String? = nil
    @State private var showingErrorAlert: Bool = false
    @State private var isImporting: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Top Sound Triggers (CarPlay Connection, Disconnection, Home Arrival)
                        topTriggerCards

                        // Section: Custom Audio Clips (WAV/MP3/M4A)
                        customClipsSection

                        // Section: Top trending presets
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
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.audio, .wav, .mp3, .mpeg4Audio],
                allowsMultipleSelection: false
            ) { result in
                handleFileImportResult(result)
            }
            .alert("Import Failed", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "An unknown error occurred while importing audio.")
            }
            .onAppear {
                loadPreferences()
            }
        }
    }

    // MARK: - Top Trigger Cards

    private var topTriggerCards: some View {
        VStack(spacing: 12) {
            // Primary: CarPlay Connection Chime
            triggerCard(
                icon: "bolt.car.fill",
                iconColor: Color.dashYellow,
                title: "CarPlay Connection Chime",
                subtitle: "Plays when CarPlay or Bluetooth connects",
                currentSoundId: connectionSoundId,
                slotKey: "connection"
            )

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
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        currentSoundId: String,
        slotKey: String
    ) -> some View {
        let sound = catalog.sounds.first(where: { $0.id == currentSoundId })
        let isPlaying = soundPlayer.currentlyPlayingId == currentSoundId

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Button {
                    if let sound {
                        soundPlayer.play(sound: sound)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.22))
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
                        HStack(spacing: 6) {
                            Text("Selected: \(sound.title)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.dashYellow)

                            if sound.isCustom {
                                Text("CUSTOM")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.dashYellow.opacity(0.2))
                                    .foregroundStyle(Color.dashYellow)
                                    .clipShape(Capsule())
                            }
                        }
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

            // Waveform visualizer strip for the selected sound
            if let sound {
                AudioWaveformView(
                    samples: sound.waveformSamples,
                    isPlaying: isPlaying,
                    tintColor: iconColor,
                    barSpacing: 2.0,
                    barCornerRadius: 1.5
                )
                .frame(height: 20)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(slotKey == "connection" ? Color.dashYellow.opacity(0.4) : Color.dashBorder, lineWidth: 1)
        )
    }

    // MARK: - Custom Audio Clips Section

    private var customClipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Audio Clips")
                    .font(ThemeFonts.hudTitle(size: 18))
                    .foregroundStyle(Color.dashTextPrimary)

                Spacer()

                Button {
                    showingFileImporter = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Import Audio")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.dashYellow)
                    .foregroundStyle(Color.black)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)

            if catalog.customSounds.isEmpty {
                // Empty state card encouraging driver customization
                Button {
                    showingFileImporter = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.badge.plus")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.dashYellow)

                        Text("Import Custom Exhaust or Chime")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)

                        Text("Upload your favorite WAV, MP3, or M4A clip (V8 rev, turbo blow-off, or custom chime) to play on CarPlay connection.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dashTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.dashSurface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.dashBorder, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    ForEach(catalog.customSounds) { sound in
                        customSoundRow(sound: sound)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func customSoundRow(sound: SoundEffectItem) -> some View {
        let isPlaying = soundPlayer.currentlyPlayingId == sound.id
        let isConnection = connectionSoundId == sound.id

        return HStack(spacing: 12) {
            Button {
                soundPlayer.play(sound: sound)
            } label: {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.dashYellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(sound.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)
                        .lineLimit(1)

                    if isConnection {
                        Text("ACTIVE CHIME")
                            .font(.system(size: 8, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.dashYellow)
                            .foregroundStyle(Color.black)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text("\(sound.durationString)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.dashTextSecondary)

                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.dashTextMuted)

                    Text("Auto-Normalized")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.dashGreen)
                }

                AudioWaveformView(
                    samples: sound.waveformSamples,
                    isPlaying: isPlaying,
                    tintColor: Color.dashYellow,
                    barSpacing: 2.0,
                    barCornerRadius: 1.0
                )
                .frame(height: 18)
                .padding(.top, 2)
            }

            Spacer()

            Menu {
                Button {
                    connectionSoundId = sound.id
                    savePreferences()
                } label: {
                    Label("Set as Connection Chime", systemImage: "bolt.car")
                }

                Button {
                    disconnectionSoundId = sound.id
                    savePreferences()
                } label: {
                    Label("Set as Disconnection Sound", systemImage: "stop.circle")
                }

                Button {
                    homeArrivalSoundId = sound.id
                    savePreferences()
                } label: {
                    Label("Set as Arrival Sound", systemImage: "house")
                }

                Divider()

                Button(role: .destructive) {
                    try? catalog.deleteCustomSound(id: sound.id)
                    if connectionSoundId == sound.id {
                        connectionSoundId = "jet_startup"
                        savePreferences()
                    }
                } label: {
                    Label("Delete Clip", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.dashTextSecondary)
                    .padding(6)
            }
        }
        .padding(12)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isConnection ? Color.dashYellow.opacity(0.5) : Color.dashBorder, lineWidth: 1)
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
                ForEach(catalog.presetSounds) { sound in
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
            VStack(alignment: .leading, spacing: 6) {
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
                        Button("Set as Connection Chime") {
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

                // Mini Waveform preview on tile
                AudioWaveformView(
                    samples: sound.waveformSamples,
                    isPlaying: isPlaying,
                    tintColor: Color.white.opacity(0.85),
                    barSpacing: 1.5,
                    barCornerRadius: 1.0
                )
                .frame(height: 14)
            }
            .padding(10)
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
        let title: LocalizedStringKey = {
            switch slot {
            case "connection": return "Select Connection Chime"
            case "disconnection": return "Select Disconnection Sound"
            default: return "Select Arrival Sound"
            }
        }()

        let categories = ["Recommend", "All", "Custom", "Engine", "Voices", "Futuristic", "Chimes", "Cinematic"]

        return NavigationStack {
            ZStack(alignment: .bottom) {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.dashTextMuted)
                        TextField("Search a sound", text: $soundSearchText)
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
                                    Text(cat)
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
                    Text("Tap ▶ to preview, tap the card to select")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.dashTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)

                    // Sound List
                    ScrollView {
                        VStack(spacing: 10) {
                            let list = catalog.sounds.filter { sound in
                                let matchesCategory: Bool = {
                                    if pickerCategory == "All" || pickerCategory == "Recommend" {
                                        return true
                                    }
                                    if pickerCategory == "Custom" {
                                        return sound.isCustom
                                    }
                                    return sound.category.rawValue.lowercased().contains(pickerCategory.lowercased())
                                }()
                                let matchesSearch = soundSearchText.isEmpty || sound.title.localizedCaseInsensitiveContains(soundSearchText)
                                return matchesCategory && matchesSearch
                            }

                            ForEach(list) { sound in
                                Button {
                                    if slot == "connection" {
                                        connectionSoundId = sound.id
                                    } else if slot == "disconnection" {
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
                                            HStack(spacing: 6) {
                                                Text(sound.title)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(Color.dashTextPrimary)

                                                if sound.isCustom {
                                                    Text("CUSTOM")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Color.dashYellow.opacity(0.2))
                                                        .foregroundStyle(Color.dashYellow)
                                                        .clipShape(Capsule())
                                                }
                                            }

                                            Text("\(sound.category.rawValue) · \(sound.durationString)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.dashTextSecondary)

                                            AudioWaveformView(
                                                samples: sound.waveformSamples,
                                                isPlaying: soundPlayer.currentlyPlayingId == sound.id,
                                                tintColor: Color.dashYellow.opacity(0.8),
                                                barSpacing: 1.5,
                                                barCornerRadius: 1.0
                                            )
                                            .frame(height: 12)
                                            .padding(.top, 1)
                                        }

                                        Spacer()

                                        let currentSelectedId: String = {
                                            switch slot {
                                            case "connection": return connectionSoundId
                                            case "disconnection": return disconnectionSoundId
                                            default: return homeArrivalSoundId
                                            }
                                        }()
                                        let isSelected = currentSelectedId == sound.id

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
                    Text("Close")
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
            .navigationTitle(title)
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

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.dashYellow)
                    }
                }
            }
        }
    }

    // MARK: - File Import Handler

    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    let imported = try await catalog.importCustomAudio(from: url)
                    await MainActor.run {
                        // Automatically set newly imported custom sound as the CarPlay connection chime
                        self.connectionSoundId = imported.id
                        self.savePreferences()
                    }
                } catch {
                    await MainActor.run {
                        self.importErrorMessage = error.localizedDescription
                        self.showingErrorAlert = true
                    }
                }
            }
        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showingErrorAlert = true
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
        case .custom:
            return LinearGradient(colors: [Color(red: 0.65, green: 0.55, blue: 0.05), Color(red: 0.18, green: 0.15, blue: 0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
        case .custom: return "waveform.badge.plus"
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
