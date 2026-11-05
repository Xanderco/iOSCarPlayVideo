import SwiftUI
import AppIntents

/// Settings › Car Extras › Car Chime: pick one short synthesized chime. A Shortcuts
/// automation can play it when the iPhone connects to the car.
public struct CarChimeView: View {
    @ObservedObject private var engine = SoundPlayerEngine.shared
    @State private var selectedId: String = SoundCatalogService.shared.selectedSound().id

    private let catalog = SoundCatalogService.shared

    public init() {}

    public var body: some View {
        List {
            Section {
                HStack(spacing: DSSpacing.md) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title2)
                        .foregroundStyle(Color.dcAccent)
                        .frame(width: 44, height: 44)
                        .background(Color.dcAccentSoft, in: RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Text(catalog.sound(withId: selectedId)?.title ?? "None")
                            .font(DSTypography.headline)
                            .foregroundStyle(Color.dcTextPrimary)
                        Text("Your car chime")
                            .font(DSTypography.footnote)
                            .foregroundStyle(Color.dcTextSecondary)
                    }
                    Spacer()
                    Button {
                        if let sound = catalog.sound(withId: selectedId) { toggle(sound) }
                    } label: {
                        Image(systemName: engine.currentlyPlayingId == selectedId ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.dcAccent)
                            .frame(minWidth: DSLayout.minTapTarget, minHeight: DSLayout.minTapTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(engine.currentlyPlayingId == selectedId ? "Stop" : "Play chime"))
                }
                .padding(.vertical, DSSpacing.xs)
            } footer: {
                Text("Every chime is generated on your iPhone. Tap one to hear it and select it.")
            }

            ForEach(SoundCategory.pickable) { category in
                Section {
                    ForEach(catalog.sounds(for: category)) { sound in
                        chimeRow(sound)
                    }
                } header: {
                    Text(category.rawValue)
                }
            }

            Section {
                stepRow(1, "Open the Shortcuts app and tap Automation, then New Automation.")
                stepRow(2, "Choose CarPlay, select Connects, and set it to Run Immediately.")
                stepRow(3, "Add the DashCast action \u{201C}Play Car Chime\u{201D}.")
                if let url = URL(string: "shortcuts://") {
                    Link(destination: url) {
                        Label("Open Shortcuts", systemImage: "arrow.up.right.square")
                    }
                }
            } header: {
                Text("Play it when you connect")
            } footer: {
                Text("Apple's Shortcuts app runs the automation. DashCast doesn't need to be open.")
            }
        }
        .tint(Color.dcAccent)
        .scrollContentBackground(.hidden)
        .background(Color.dcBackgroundElevated.ignoresSafeArea())
        .navigationTitle("Car Chime")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { engine.stop() }
    }

    private func chimeRow(_ sound: SoundEffectItem) -> some View {
        let isSelected = sound.id == selectedId
        let isPlaying = engine.currentlyPlayingId == sound.id
        return Button {
            select(sound)
        } label: {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "music.note")
                    .foregroundStyle(isPlaying ? Color.dcAccent : Color.dcTextSecondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(sound.title)
                    .foregroundStyle(Color.dcTextPrimary)
                Spacer()
                Text("\(sound.notes.count) note\(sound.notes.count == 1 ? "" : "s")")
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dcTextTertiary)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.dcAccent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(sound.title))
        .accessibilityValue(Text(isSelected ? "Selected" : ""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityHint(Text("Plays and selects this chime"))
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.md) {
            Text("\(number)")
                .font(DSTypography.badge)
                .foregroundStyle(Color.dcOnAccent)
                .frame(width: 22, height: 22)
                .background(Color.dcAccent, in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(DSTypography.subheadline)
                .foregroundStyle(Color.dcTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Step \(number). \(text)"))
    }

    private func select(_ sound: SoundEffectItem) {
        selectedId = sound.id
        var prefs = PersistenceController.shared.loadUserPreferences()
        prefs.connectionSoundId = sound.id
        PersistenceController.shared.saveUserPreferences(prefs)
        engine.play(sound: sound)
    }

    private func toggle(_ sound: SoundEffectItem) {
        if engine.currentlyPlayingId == sound.id {
            engine.stop()
        } else {
            engine.play(sound: sound)
        }
    }
}

// MARK: - Shortcuts action

/// "Play Car Chime": plays the chime selected in Settings › Car Extras › Car Chime.
/// Meant for a Shortcuts automation on CarPlay "Connects".
public struct PlayCarChimeIntent: AppIntent {
    public static let title: LocalizedStringResource = "Play Car Chime"

    public init() {}

    public func perform() async throws -> some IntentResult {
        let duration = await MainActor.run { () -> Double in
            let sound = SoundCatalogService.shared.selectedSound()
            SoundPlayerEngine.shared.play(sound: sound)
            return sound.duration
        }
        // Keep the intent alive until the chime has finished.
        try? await Task.sleep(nanoseconds: UInt64((duration + 0.2) * 1_000_000_000))
        return .result()
    }
}

#Preview("Car Chime") {
    NavigationStack { CarChimeView() }
        .preferredColorScheme(.dark)
}
