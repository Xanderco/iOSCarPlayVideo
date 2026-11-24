import SwiftUI

public struct ShortcutsGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var automationService = DashCastAutomationService.shared
    @State private var copiedPhrase: String?
    @State private var showingTestFeedback: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        headerSection

                        // Interactive Test Actions
                        testActionsSection

                        // Voice Triggers (Hey Siri)
                        siriVoiceTriggersSection

                        // CarPlay & In-Car Automations
                        carPlayAutomationsSection

                        // Step-by-Step Setup
                        stepByStepSection

                        launchShortcutsButton
                            .padding(.top, 10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Siri & Automations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.dashTextSecondary)
                }
            }
            .overlay(alignment: .bottom) {
                if let feedback = showingTestFeedback {
                    toastView(message: feedback)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.badge.automatic.fill")
                    .foregroundStyle(Color.dashYellow)
                    .font(.system(size: 20))
                Text("Hands-Free In-Car Automations")
                    .font(ThemeFonts.hudTitle(size: 20))
                    .foregroundStyle(Color.dashTextPrimary)
            }

            Text("Control DashCast completely hands-free while driving using Siri voice commands and automatic CarPlay trigger workflows.")
                .font(ThemeFonts.hudCaption(size: 14))
                .foregroundStyle(Color.dashTextSecondary)
        }
    }

    // MARK: - Interactive Test Actions

    private var testActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK TEST INTENTS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.dashYellow)
                .tracking(1.2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                testCard(title: "Start Drive", icon: "steeringwheel", color: Color.dashYellow) {
                    automationService.triggerStartTrip()
                    showFeedback("Drive recording started!")
                }

                testCard(title: "Resume Cast", icon: "play.tv.fill", color: Color.dashCyan) {
                    automationService.triggerResumeCast()
                    showFeedback("Video playback resumed!")
                }

                testCard(title: "Night HUD", icon: "moon.fill", color: Color.dashAmber) {
                    automationService.triggerToggleNightHUD()
                    showFeedback("Night HUD toggled!")
                }

                testCard(title: "Welcome Chime", icon: "bell.fill", color: Color.dashGreen) {
                    automationService.triggerPlayChime()
                    showFeedback("Welcome chime triggered!")
                }
            }
        }
    }

    private func testCard(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(color)
                    }
                    Spacer()
                    Text("TEST")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.dashTextPrimary)
            }
            .padding(12)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.dashBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Siri Voice Triggers

    private var siriVoiceTriggersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SIRI VOICE COMMANDS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.dashYellow)
                .tracking(1.2)

            VStack(spacing: 10) {
                siriPhraseRow(phrase: "Hey Siri, start drive in DashCast", intent: "StartTripRecordingIntent")
                siriPhraseRow(phrase: "Hey Siri, resume video in DashCast", intent: "ResumeLastCastIntent")
                siriPhraseRow(phrase: "Hey Siri, toggle night HUD in DashCast", intent: "ToggleNightHUDIntent")
                siriPhraseRow(phrase: "Hey Siri, play car chime in DashCast", intent: "PlayCarChimeIntent")
            }
        }
    }

    private func siriPhraseRow(phrase: String, intent: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.dashYellow)

            Text(phrase)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.dashTextPrimary)

            Spacer()

            Button {
                UIPasteboard.general.string = phrase
                showFeedback("Copied phrase!")
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextSecondary)
            }
        }
        .padding(12)
        .background(Color.dashSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dashBorder, lineWidth: 1)
        )
    }

    // MARK: - CarPlay Automations

    private var carPlayAutomationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECOMMENDED AUTOMATIONS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.dashYellow)
                .tracking(1.2)

            automationCard(
                trigger: "When CarPlay Connects",
                icon: "car.front.waves.up.fill",
                color: Color.dashYellow,
                actionDescription: "Auto-launch DashCast & play your personalized greeting chime through in-dash speakers."
            )

            automationCard(
                trigger: "When Driving Focus Turns On",
                icon: "location.north.circle.fill",
                color: Color.dashCyan,
                actionDescription: "Immediately start telemetry recording and enable night HUD without touching your iPhone."
            )

            automationCard(
                trigger: "When CarPlay Disconnects",
                icon: "parkingsign.circle.fill",
                color: Color.dashAmber,
                actionDescription: "Automatically save trip summary, calculate efficiency score, and prompt parking photo."
            )
        }
    }

    private func automationCard(trigger: String, icon: String, color: Color, actionDescription: String) -> some View {
        AutomotiveCard {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(trigger)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text(actionDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                }
            }
        }
    }

    // MARK: - Step By Step Section

    private var stepByStepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW TO CONFIGURE IN APPLE SHORTCUTS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.dashYellow)
                .tracking(1.2)

            stepCard(
                stepNumber: "1",
                title: "Open Shortcuts Automation Tab",
                description: "Open Apple's Shortcuts app and tap the 'Automation' tab at the bottom center."
            )

            stepCard(
                stepNumber: "2",
                title: "Select CarPlay or Bluetooth Trigger",
                description: "Tap '+' and pick 'CarPlay' (When CarPlay Connects) or 'Bluetooth' (When your car connects). Choose 'Run Immediately'."
            )

            stepCard(
                stepNumber: "3",
                title: "Add DashCast App Intent",
                description: "Search for 'DashCast' under App Actions, select 'Start Drive' or 'Play Chime', and tap Done."
            )
        }
    }

    private func stepCard(stepNumber: String, title: String, description: String) -> some View {
        AutomotiveCard {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.dashYellow.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Text(stepNumber)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.dashYellow)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextSecondary)
                }
            }
        }
    }

    private var launchShortcutsButton: some View {
        GlowButton(title: "Open Apple Shortcuts", iconName: "arrow.up.forward.app.fill", gradient: .dashAccentGradient) {
            automationService.launchShortcutsApp()
        }
    }

    private func showFeedback(_ text: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingTestFeedback = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if showingTestFeedback == text {
                    showingTestFeedback = nil
                }
            }
        }
    }

    private func toastView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.dashYellow)
            Text(message)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.85))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.dashYellow.opacity(0.5), lineWidth: 1))
        .shadow(radius: 8)
    }
}
