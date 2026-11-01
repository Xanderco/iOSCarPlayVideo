import SwiftUI

public struct WidgetsHomeView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color.dashBlue)

                    Text("CarPlay & Home Widgets")
                        .font(ThemeFonts.hudTitle(size: 24))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text("Personalize your dashboard with 100+ car brands and custom widgets.")
                        .font(ThemeFonts.hudCaption(size: 14))
                        .foregroundStyle(Color.dashTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle("Widgets")
        }
    }
}
