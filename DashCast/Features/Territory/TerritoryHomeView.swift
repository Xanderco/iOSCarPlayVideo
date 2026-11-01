import SwiftUI

public struct TerritoryHomeView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color.dashCyan)

                    Text("Claim Your Streets")
                        .font(ThemeFonts.hudTitle(size: 24))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text("Drive through city streets to conquer hexagons and level up your driver rank.")
                        .font(ThemeFonts.hudCaption(size: 14))
                        .foregroundStyle(Color.dashTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle("Territory")
        }
    }
}
