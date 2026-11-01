import SwiftUI

public struct ShortcutsGuideView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

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

    private func stepCard(stepNumber: String, title: String, description: String) -> some View {
        AutomotiveCard {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.dashCyan.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Text(stepNumber)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.dashCyan)
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
