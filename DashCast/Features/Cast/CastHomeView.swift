import SwiftUI

public struct CastHomeView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(LinearGradient.dashAccentGradient)

                    Text("Cast & Video")
                        .font(ThemeFonts.hudTitle(size: 24))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text("Play your media on compatible CarPlay displays while parked.")
                        .font(ThemeFonts.hudCaption(size: 14))
                        .foregroundStyle(Color.dashTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle("Cast")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.showPaywall = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Color.dashGold)
                            Text("PRO")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.dashGold)
                        }
                    }
                }
            }
        }
    }
}
