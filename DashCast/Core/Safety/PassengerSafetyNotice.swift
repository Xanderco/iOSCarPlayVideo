import SwiftUI

/// Stores whether the user acknowledged the passenger-only safety notice.
public enum PassengerSafetyNotice {
    public static let acceptedKey = "dashcast_passenger_notice_accepted_v1"

    /// The notice is skipped only for automated runs: App Store screenshots (`-seedDemoData`) and XCUITests (`-UITests`).
    public static var shouldSkip: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-seedDemoData") || args.contains("-UITests")
    }
}

/// First-launch screen: video is for passengers or while parked, never for the driver while moving.
public struct PassengerSafetyNoticeView: View {
    private let onAccept: () -> Void

    public init(onAccept: @escaping () -> Void) {
        self.onAccept = onAccept
    }

    public var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer(minLength: 20)

                ZStack {
                    Circle()
                        .fill(Color.dashGreen.opacity(0.15))
                        .frame(width: 112, height: 112)
                    Image(systemName: "car.side.and.exclamationmark")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(Color.dashGreen)
                }
                .accessibilityHidden(true)

                Text("Passengers & parked only")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.dashTextPrimary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    row("eye.slash.fill", "Never watch video while driving. The driver must keep their eyes on the road.")
                    row("parkingsign.circle.fill", "Video on a car display is for passengers, or when the vehicle is parked (for example while charging).")
                    row("hand.raised.fill", "Obey local laws. Some regions ban any screen visible to the driver while moving.")
                    row("music.note", "While driving, use audio only.")
                }
                .padding(18)
                .background(Color.dashSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))

                Spacer()

                Button(action: onAccept) {
                    Text("I Understand")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.dashGreen)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("passengerNoticeAccept")
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .interactiveDismissDisabled()
    }

    private func row(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Color.dashGreen)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.dashTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
