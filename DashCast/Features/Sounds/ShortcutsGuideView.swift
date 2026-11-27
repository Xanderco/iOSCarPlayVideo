import SwiftUI

/// Localized copy and step definitions for `ShortcutsGuideView`.
public enum ShortcutsGuideCopy {
    public struct Step: Equatable {
        nonisolated public let number: String
        nonisolated public let titleKey: String
        nonisolated public let descriptionKey: String

        nonisolated public init(number: String, titleKey: String, descriptionKey: String) {
            self.number = number
            self.titleKey = titleKey
            self.descriptionKey = descriptionKey
        }

        @MainActor public var localizedTitleKey: LocalizedStringKey {
            LocalizedStringKey(titleKey)
        }

        @MainActor public var localizedDescriptionKey: LocalizedStringKey {
            LocalizedStringKey(descriptionKey)
        }
    }

    nonisolated public static let headerTitleString = "Configure Siri Shortcuts Automation"
    nonisolated public static let headerSubtitleString = "Follow these 4 simple steps in Apple's Shortcuts app to trigger your car personality sounds automatically whenever you get in or out of your car."
    nonisolated public static let step1TitleString = "Open Apple Shortcuts"
    nonisolated public static let step1DescriptionString = "Open the pre-installed 'Shortcuts' app on your iPhone and tap the 'Automation' tab at the bottom center."
    nonisolated public static let step2TitleString = "Create CarPlay Automation"
    nonisolated public static let step2DescriptionString = "Tap '+' (New Automation) and select 'CarPlay' (or 'Bluetooth'). Choose 'When CarPlay Connects' and select 'Run Immediately' (disable 'Ask Before Running')."
    nonisolated public static let step3TitleString = "Add DashCast Action"
    nonisolated public static let step3DescriptionString = "Tap 'New Blank Automation', search for 'DashCast' or 'Open App', and add the 'Play Connection Sound' intent."
    nonisolated public static let step4TitleString = "Done! Enjoy the Experience"
    nonisolated public static let step4DescriptionString = "Whenever your iPhone plugs into or connects wirelessly to CarPlay, your chosen sound will immediately play through your car's stereo system!"
    nonisolated public static let launchButtonTitleString = "Launch Apple Shortcuts"
    nonisolated public static let navigationTitleString = "Automations Guide"
    nonisolated public static let closeButtonString = "Close"

    nonisolated public static let steps: [Step] = [
        Step(number: "1", titleKey: step1TitleString, descriptionKey: step1DescriptionString),
        Step(number: "2", titleKey: step2TitleString, descriptionKey: step2DescriptionString),
        Step(number: "3", titleKey: step3TitleString, descriptionKey: step3DescriptionString),
        Step(number: "4", titleKey: step4TitleString, descriptionKey: step4DescriptionString)
    ]

    nonisolated public static let allLocalizationKeys: [String] = [
        headerTitleString,
        headerSubtitleString,
        step1TitleString,
        step1DescriptionString,
        step2TitleString,
        step2DescriptionString,
        step3TitleString,
        step3DescriptionString,
        step4TitleString,
        step4DescriptionString,
        launchButtonTitleString,
        navigationTitleString,
        closeButtonString
    ]

    @MainActor public static var headerTitleKey: LocalizedStringKey { LocalizedStringKey(headerTitleString) }
    @MainActor public static var headerSubtitleKey: LocalizedStringKey { LocalizedStringKey(headerSubtitleString) }
    @MainActor public static var launchButtonTitleKey: LocalizedStringKey { LocalizedStringKey(launchButtonTitleString) }
    @MainActor public static var navigationTitleKey: LocalizedStringKey { LocalizedStringKey(navigationTitleString) }
    @MainActor public static var closeButtonKey: LocalizedStringKey { LocalizedStringKey(closeButtonString) }
}

public struct ShortcutsGuideView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(ShortcutsGuideCopy.headerTitleKey)
                            .font(ThemeFonts.hudTitle(size: 22))
                            .foregroundStyle(Color.dashTextPrimary)

                        Text(ShortcutsGuideCopy.headerSubtitleKey)
                            .font(ThemeFonts.hudCaption(size: 14))
                            .foregroundStyle(Color.dashTextSecondary)

                        ForEach(ShortcutsGuideCopy.steps, id: \.number) { step in
                            stepCard(
                                stepNumber: step.number,
                                title: step.localizedTitleKey,
                                description: step.localizedDescriptionKey
                            )
                        }

                        GlowButton(title: ShortcutsGuideCopy.launchButtonTitleKey, iconName: "arrow.up.forward.app.fill", gradient: .dashAccentGradient) {
                            if let url = URL(string: "shortcuts://") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
            }
            .navigationTitle(ShortcutsGuideCopy.navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(ShortcutsGuideCopy.closeButtonKey) {
                        dismiss()
                    }
                    .foregroundStyle(Color.dashTextSecondary)
                }
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
