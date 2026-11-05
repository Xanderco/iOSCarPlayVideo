import SwiftUI

/// First-run walkthrough (5 pages): what DashCast does, sources, Drive, the passenger-only
/// acknowledgement (required) and the one-time Pro offer (always skippable).
/// Visuals are drawn in SwiftUI — no stock or third-party imagery.
/// Completing it records the passenger notice as accepted (same key as `PassengerSafetyNotice`).
public struct WelcomeOnboardingView: View {
    private let onFinish: () -> Void

    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var acknowledgedSafety = false
    @State private var glow = false

    private let safetyPage = 3
    private let pageCount = 5

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            Color.dcBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    pageView(
                        hero: AnyView(cinemaHero),
                        title: "Your car, your cinema",
                        subtitle: "Play your own videos and channels on the car display while you're parked."
                    ).tag(0)

                    pageView(
                        hero: AnyView(sourcesHero),
                        title: "Bring your own sources",
                        subtitle: "M3U and M3U8 playlists, Jellyfin and Emby servers, your Files and Photos. DashCast includes no channels of its own."
                    ).tag(1)

                    pageView(
                        hero: AnyView(driveHero),
                        title: "Every trip, remembered",
                        subtitle: "Turn on automatic trips and DashCast records your drives with route, distance and a smooth-driving score."
                    ).tag(2)

                    safetyPageView.tag(safetyPage)

                    pageView(
                        hero: AnyView(proHero),
                        title: "Pay once, keep it forever",
                        subtitle: "DashCast Pro is a single purchase. No subscriptions, no renewals. Everything basic stays free."
                    ).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: page) { _, newValue in
                    // You cannot swipe past the safety page without acknowledging it.
                    if newValue > safetyPage && !acknowledgedSafety { page = safetyPage }
                }

                footer
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
        }
        .accessibilityIdentifier("Onboarding")
    }

    // MARK: Page scaffold

    private func pageView(hero: AnyView, title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            hero
                .frame(maxWidth: .infinity)
                .frame(height: 380)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Color.dcBackground], startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                }
                .clipped()
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.dcTextPrimary)
                Text(subtitle)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.dcTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
    }

    private var safetyPageView: some View {
        VStack(spacing: 0) {
            safetyHero
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Color.dcBackground], startPoint: .top, endPoint: .bottom)
                        .frame(height: 100)
                }
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                Text("For passengers only")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dcTextPrimary)
                Text("Video on a car display is for passengers or while parked. DashCast pauses video when it detects the car is moving.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.dcTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $acknowledgedSafety) {
                    Text("I won't watch or operate DashCast while driving.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.dcTextPrimary)
                }
                .tint(Color.dcAccent)
                .padding(16)
                .background(Color.dcSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("Onboarding_SafetyToggle")
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 14) {
            Button(action: advance) {
                HStack {
                    Text(primaryTitle)
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.dcOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Capsule().fill(Color.dcAccent))
                .opacity(page == safetyPage && !acknowledgedSafety ? 0.4 : 1)
            }
            .disabled(page == safetyPage && !acknowledgedSafety)
            .accessibilityIdentifier("Onboarding_Continue")

            if page == pageCount - 1 {
                Button("Continue with the free version") { onFinish() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.dcTextSecondary)
                    .accessibilityIdentifier("Onboarding_Free")
            }

            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.dcAccent : Color.dcTextTertiary.opacity(0.5))
                        .frame(width: index == page ? 18 : 7, height: 7)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Page \(page + 1) of \(pageCount)"))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private var primaryTitle: String {
        switch page {
        case safetyPage: return acknowledgedSafety ? "I understand" : "Please confirm above"
        case pageCount - 1: return "See DashCast Pro"
        default: return "Continue"
        }
    }

    private func advance() {
        if page < pageCount - 1 {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { page += 1 }
        } else {
            onFinish()
            // Let the full-screen cover dismiss before presenting the paywall sheet.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { appState.showPaywall = true }
        }
    }

    // MARK: Hero visuals (pure SwiftUI)

    private func heroBackground(_ colors: [Color]) -> some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Color.dcAccent.opacity(glow ? 0.35 : 0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: 80, y: -60)
        }
    }

    private var cinemaHero: some View {
        ZStack {
            heroBackground([Color(red: 0.05, green: 0.08, blue: 0.14), Color(red: 0.10, green: 0.05, blue: 0.20)])
            // Dashboard with a wide car display
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .frame(width: 320, height: 190)
                .offset(y: 70)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color.dcAccent.opacity(0.9), Color(red: 0.1, green: 0.4, blue: 0.9)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 270, height: 150)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 8)
                )
                .shadow(color: Color.dcAccent.opacity(glow ? 0.7 : 0.35), radius: 30)
                .offset(y: 20)
            Image(systemName: "steeringwheel")
                .font(.system(size: 90, weight: .thin))
                .foregroundStyle(.white.opacity(0.18))
                .offset(x: -120, y: 150)
        }
    }

    private var sourcesHero: some View {
        ZStack {
            heroBackground([Color(red: 0.04, green: 0.10, blue: 0.12), Color(red: 0.03, green: 0.05, blue: 0.10)])
            let items: [(String, String)] = [
                ("list.bullet.rectangle.fill", "M3U"), ("server.rack", "Jellyfin"), ("externaldrive.fill", "Emby"),
                ("folder.fill", "Files"), ("photo.on.rectangle", "Photos"), ("qrcode.viewfinder", "QR")
            ]
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(96), spacing: 14), count: 3), spacing: 14) {
                ForEach(items, id: \.1) { icon, label in
                    VStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.dcAccent)
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(width: 96, height: 96)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .offset(y: 10)
        }
    }

    private var driveHero: some View {
        ZStack {
            heroBackground([Color(red: 0.03, green: 0.09, blue: 0.07), Color(red: 0.05, green: 0.06, blue: 0.12)])
            // Stylised route
            Path { p in
                p.move(to: CGPoint(x: 40, y: 300))
                p.addCurve(to: CGPoint(x: 330, y: 90), control1: CGPoint(x: 150, y: 120), control2: CGPoint(x: 220, y: 330))
            }
            .stroke(Color.dcAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [1, 14]))
            .frame(width: 370, height: 380)
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.dcAccent, .white)
                .offset(x: 140, y: -100)
            VStack(spacing: 2) {
                Text("92")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("SMOOTH SCORE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.dcAccent)
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .offset(x: -80, y: 40)
        }
    }

    private var safetyHero: some View {
        ZStack {
            heroBackground([Color(red: 0.12, green: 0.08, blue: 0.03), Color(red: 0.05, green: 0.05, blue: 0.08)])
            Image(systemName: "person.2.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.9))
                .offset(x: -40, y: 10)
            Image(systemName: "parkingsign.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white, Color.dcWarning)
                .offset(x: 80, y: -40)
        }
    }

    private var proHero: some View {
        ZStack {
            heroBackground([Color(red: 0.12, green: 0.09, blue: 0.02), Color(red: 0.06, green: 0.04, blue: 0.10)])
            Image(systemName: "crown.fill")
                .font(.system(size: 110))
                .foregroundStyle(LinearGradient(colors: [Color.dcPro, .white], startPoint: .bottom, endPoint: .top))
                .shadow(color: Color.dcPro.opacity(glow ? 0.8 : 0.4), radius: 40)
            Text("ONE-TIME")
                .font(.system(size: 13, weight: .heavy))
                .tracking(2)
                .foregroundStyle(Color.dcOnAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.dcPro))
                .offset(y: 95)
        }
    }
}

#Preview("Welcome onboarding") {
    WelcomeOnboardingView(onFinish: {})
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
