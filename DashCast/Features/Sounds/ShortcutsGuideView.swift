import SwiftUI

public enum ShortcutsGuideSoundResolver {
    public static let localizationKeys: [String] = [
        "Automations Guide",
        "Configure Siri Shortcuts Automation",
        "Follow these 4 simple steps in Apple's Shortcuts app to trigger your car personality sounds automatically whenever you get in or out of your car.",
        "Open Apple Shortcuts",
        "Open the pre-installed 'Shortcuts' app on your iPhone and tap the 'Automation' tab at the bottom center.",
        "Create CarPlay Automation",
        "Tap '+' (New Automation) and select 'CarPlay' (or 'Bluetooth'). Choose 'When CarPlay Connects' and select 'Run Immediately' (disable 'Ask Before Running').",
        "Add DashCast Action",
        "Tap 'New Blank Automation', search for 'DashCast' or 'Open App', and add the 'Play Connection Sound' intent.",
        "Done! Enjoy the Experience",
        "Whenever your iPhone plugs into or connects wirelessly to CarPlay, your chosen sound will immediately play through your car's stereo system!",
        "Launch Apple Shortcuts",
        "Test Connection Sound",
        "Preview the chime configured for CarPlay connection.",
        "Play",
        "Stop",
        "Close"
    ]

    public static func resolveConnectionSound(
        from preferences: UserPreferences,
        catalog: SoundCatalogService = .shared
    ) -> SoundEffectItem? {
        if let configuredId = preferences.connectionSoundId,
           let matched = catalog.sounds.first(where: { $0.id == configuredId }) {
            return matched
        }
        return catalog.sounds.first(where: { $0.id == "jet_startup" }) ?? catalog.sounds.first
    }
}

public struct ShortcutsGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var soundPlayer = SoundPlayerEngine.shared
    @State private var preferences: UserPreferences = PersistenceController.shared.loadUserPreferences()

    public init() {}

    private var connectionSound: SoundEffectItem? {
        ShortcutsGuideSoundResolver.resolveConnectionSound(from: preferences)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Configure Siri Shortcuts Automation")
                            .font(ThemeFonts.hudTitle(size: 22))
                            .foregroundStyle(Color.dashTextPrimary)

                        Text("Follow these 4 simple steps in Apple's Shortcuts app to trigger your car personality sounds automatically whenever you get in or out of your car.")
                            .font(ThemeFonts.hudCaption(size: 14))
                            .foregroundStyle(Color.dashTextSecondary)

                        if let sound = connectionSound {
                            testConnectionSoundCard(sound: sound)
                        }

                        stepCard(
                            stepNumber: "1",
                            title: "Open Apple Shortcuts",
                            description: "Open the pre-installed 'Shortcuts' app on your iPhone and tap the 'Automation' tab at the bottom center."
                        )

                        stepCard(
                            stepNumber: "2",
                            title: "Create CarPlay Automation",
                            description: "Tap '+' (New Automation) and select 'CarPlay' (or 'Bluetooth'). Choose 'When CarPlay Connects' and select 'Run Immediately' (disable 'Ask Before Running')."
                        )

                        stepCard(
                            stepNumber: "3",
                            title: "Add DashCast Action",
                            description: "Tap 'New Blank Automation', search for 'DashCast' or 'Open App', and add the 'Play Connection Sound' intent."
                        )

                        stepCard(
                            stepNumber: "4",
                            title: "Done! Enjoy the Experience",
                            description: "Whenever your iPhone plugs into or connects wirelessly to CarPlay, your chosen sound will immediately play through your car's stereo system!"
                        )

                        GlowButton(title: "Launch Apple Shortcuts", iconName: "arrow.up.forward.app.fill", gradient: .dashAccentGradient) {
                            if let url = URL(string: "shortcuts://") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Automations Guide")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                preferences = PersistenceController.shared.loadUserPreferences()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.dashTextSecondary)
                }
            }
        }
    }

    private func testConnectionSoundCard(sound: SoundEffectItem) -> some View {
        let isPlaying = soundPlayer.currentlyPlayingId == sound.id

        return AutomotiveCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(sound.color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: isPlaying ? "waveform" : "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(sound.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Test Connection Sound")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text(sound.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.dashYellow)

                    Text("Preview the chime configured for CarPlay connection.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                }

                Spacer()

                Button {
                    if isPlaying {
                        soundPlayer.stop()
                    } else {
                        soundPlayer.play(sound: sound)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isPlaying ? "Stop" : "Play")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isPlaying ? Color.dashOrange : Color.dashYellow)
                    .clipShape(Capsule())
                }
                .accessibilityIdentifier("ShortcutsGuide_TestConnectionSoundButton")
            }
        }
    }

    private func stepCard(stepNumber: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        AutomotiveCard {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.dashYellow.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Text(stepNumber)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.dashYellow)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dashTextSecondary)
                }
            }
        }
    }
}
