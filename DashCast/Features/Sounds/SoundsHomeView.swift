import SwiftUI

public struct SoundsHomeView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color.dashGreen)

                    Text("Car Personality Sounds")
                        .font(ThemeFonts.hudTitle(size: 24))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text("Custom sounds for CarPlay connection, disconnection, and arrival.")
                        .font(ThemeFonts.hudCaption(size: 14))
                        .foregroundStyle(Color.dashTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle("Sounds")
        }
    }
}
