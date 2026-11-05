import SwiftUI

// MARK: - Passenger safety

/// The passenger-only safety notice. Shown in onboarding (must be acknowledged) and in Settings › Car.
public struct SafetyNoticeView: View {
    public init() {}

    public var body: some View {
        List {
            Section {
                SafetyNoticeContent()
                    .padding(.vertical, DSSpacing.sm)
            }
            Section {
                Text("DashCast never asks you to interact with it while the car is moving. If you are the driver, set things up before you leave or let a passenger do it.")
                    .font(DSTypography.footnote)
                    .foregroundStyle(Color.dcTextSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dcBackgroundElevated.ignoresSafeArea())
        .navigationTitle("Passenger Safety")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Reusable body of the safety notice (icon list). Used by onboarding and Settings.
public struct SafetyNoticeContent: View {
    public init() {}

    public struct Point: Identifiable {
        public let icon: String
        public let title: String
        public let detail: String
        public var id: String { title }
        init(_ icon: String, _ title: String, _ detail: String) {
            self.icon = icon
            self.title = title
            self.detail = detail
        }
    }

    public static let points: [Point] = [
        Point("person.2.fill", "Made for passengers",
         "Video on the car display is for passengers, or for everyone while the car is parked."),
        Point("hand.raised.fill", "Drivers: eyes on the road",
         "Never watch video or operate DashCast while driving."),
        Point("parkingsign.circle.fill", "Parked is the time to set up",
         "Add sources, pick channels and change settings before you set off."),
        Point("building.columns.fill", "Follow local law",
         "Rules about screens in cars differ by country and state. You are responsible for following them.")
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            ForEach(Self.points) { point in
                HStack(alignment: .top, spacing: DSSpacing.md) {
                    Image(systemName: point.icon)
                        .font(.title3)
                        .foregroundStyle(Color.dcAccent)
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Text(point.title)
                            .font(DSTypography.headline)
                            .foregroundStyle(Color.dcTextPrimary)
                        Text(point.detail)
                            .font(DSTypography.subheadline)
                            .foregroundStyle(Color.dcTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Privacy policy

/// In-app summary of the privacy policy. The full hosted version lives at `AppLinks.privacyPolicy`.
public struct PrivacyPolicyView: View {
    public init() {}

    private struct PolicySection: Identifiable {
        let title: String
        let body: String
        var id: String { title }
        init(_ title: String, _ body: String) {
            self.title = title
            self.body = body
        }
    }

    private let sections: [PolicySection] = [
        PolicySection("No account, no tracking",
         "DashCast has no sign-in and no advertising. We do not use third-party analytics or tracking SDKs, and we do not sell or share personal data."),
        PolicySection("What stays on your iPhone",
         "Your sources and playlists, favorites, Car Screen text, chime choice, recorded drives and app settings are stored only on this device. Deleting the app deletes them."),
        PolicySection("Network requests",
         "DashCast connects only to the playlist and video addresses you add, and to Apple for purchases. Those servers are run by whoever provides the content, under their own privacy policies."),
        PolicySection("Location",
         "Location is used only by Drive to record your trips' route, distance and speed. Routes are saved on this iPhone and never uploaded. You can delete trips, or turn location off in iOS Settings at any time."),
        PolicySection("Photos and files",
         "DashCast reads only the videos and playlist files you pick. It does not scan your library."),
        PolicySection("Purchases",
         "Purchases are processed by Apple. We receive no payment details."),
        PolicySection("Contact",
         "Questions? Email \(AppLinks.supportEmail).")
    ]

    public var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    Text(section.body)
                        .font(DSTypography.body)
                        .foregroundStyle(Color.dcTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text(section.title)
                }
            }
            Section {
                Link(destination: AppLinks.privacyPolicy) {
                    Label("Full privacy policy", systemImage: "arrow.up.right.square")
                }
                Link(destination: AppLinks.termsOfUse) {
                    Label("Terms of Use", systemImage: "arrow.up.right.square")
                }
            }
        }
        .tint(Color.dcAccent)
        .scrollContentBackground(.hidden)
        .background(Color.dcBackgroundElevated.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Safety") {
    NavigationStack { SafetyNoticeView() }
        .preferredColorScheme(.dark)
}

#Preview("Privacy") {
    NavigationStack { PrivacyPolicyView() }
}
