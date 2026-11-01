import SwiftUI

public struct DriveHomeView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    NeonGaugeView(
                        value: 0,
                        title: "CURRENT SPEED",
                        unit: appState.useMilesPerHour ? "MPH" : "KM/H"
                    )

                    Text("Drive Telemetry")
                        .font(ThemeFonts.hudTitle(size: 22))
                        .foregroundStyle(Color.dashTextPrimary)

                    Text("Real-time speed, scoring and trip recording.")
                        .font(ThemeFonts.hudCaption(size: 14))
                        .foregroundStyle(Color.dashTextSecondary)
                }
            }
            .navigationTitle("Drive")
        }
    }
}
