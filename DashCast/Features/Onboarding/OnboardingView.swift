import SwiftUI

/// First-run flow: five full-screen, swipeable pages, each with a SwiftUI-drawn hero (no stock or generated
/// imagery), a bold title, one subtitle line and a big Continue button. The passenger-safety page needs an
/// explicit "I understand" before the flow can move on. Shown once; Settings › "Show Welcome Again" replays it.
/// No permissions are requested here: Drive asks for location / notifications in context.
public struct OnboardingView: View {
    /// Completing onboarding means the passenger-only notice was acknowledged, so both share one key.
    public static let completedKey = PassengerSafetyNotice.acceptedKey

    /// `-forceOnboarding` shows the flow even for UI-test / screenshot runs (used by `OnboardingUITests`).
    public static var isForcedForLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-forceOnboarding")
    }

    /// Skip for automated runs (screenshots, UI tests, unit-test hosts) unless explicitly forced.
    public static var shouldSkipForLaunch: Bool {
        if isForcedForLaunch { return false }
        let info = ProcessInfo.processInfo
        if PassengerSafetyNotice.shouldSkip { return true }
        if info.environment["XCTestConfigurationFilePath"] != nil { return true }
        return info.arguments.contains("-skipOnboarding")
    }

    /// Resets the completion flag for `-forceOnboarding` launches. Called once from `AppState.init`.
    public static func applyLaunchOverrides(defaults: UserDefaults = .standard) {
        if isForcedForLaunch {
            defaults.set(false, forKey: completedKey)
        }
    }

    enum Page: Int, CaseIterable {
        case cinema, sources, passengers, privacy, payOnce
    }

    @EnvironmentObject private var appState: AppState
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page: Page = .cinema
    @State private var acknowledgedSafety = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.dcBackground.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(Page.allCases, id: \.self) { item in
                    pageView(item)
                        .tag(item)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("Onboarding_Page_\(item.rawValue + 1)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .top)
            // Swiping past the safety page snaps back until it is acknowledged.
            .onChange(of: page) { _, newValue in
                if newValue.rawValue > Page.passengers.rawValue && !acknowledgedSafety {
                    page = .passengers
                }
            }

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomControls
            }
        }
        .environment(\.colorScheme, .dark)
        .interactiveDismissDisabled()
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            Spacer()
            if page.rawValue < Page.passengers.rawValue {
                Button("Skip") { go(to: .passengers) }
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(minWidth: DSLayout.minTapTarget, minHeight: DSLayout.minTapTarget)
                    .accessibilityIdentifier("Onboarding_Skip")
            }
        }
        .padding(.horizontal, DSSpacing.screenGutter)
        .frame(minHeight: DSLayout.minTapTarget)
    }

    private var bottomControls: some View {
        VStack(spacing: DSSpacing.lg) {
            pageDots

            switch page {
            case .passengers:
                PrimaryButton(acknowledgedSafety ? "Continue" : "Acknowledge to continue") { go(to: .privacy) }
                    .disabled(!acknowledgedSafety)
                    .opacity(acknowledgedSafety ? 1 : 0.45)
                    .accessibilityIdentifier("Onboarding_Continue")
            case .payOnce:
                PrimaryButton("Start Watching") { finish(showPro: false) }
                    .accessibilityIdentifier("Onboarding_Finish")
                PrimaryButton("See DashCast Pro", kind: .tertiary) { finish(showPro: true) }
                    .accessibilityIdentifier("Onboarding_SeePro")
            default:
                PrimaryButton("Continue") { advance() }
                    .accessibilityIdentifier("Onboarding_Continue")
            }
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.bottom, DSSpacing.lg)
    }

    private var pageDots: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(Page.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == page ? Color.dcAccent : Color.white.opacity(0.25))
                    .frame(width: item == page ? 22 : 8, height: 8)
            }
        }
        .animation(DSMotion.animation(DSMotion.quick, reduceMotion: reduceMotion), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(page.rawValue + 1) of \(Page.allCases.count)"))
        .accessibilityIdentifier("Onboarding_PageDots")
    }

    // MARK: Pages

    @ViewBuilder
    private func pageView(_ item: Page) -> some View {
        switch item {
        case .cinema:
            OnboardingPageLayout(
                title: "Your car, your cinema",
                subtitle: "Watch your own videos on the car display while you're parked."
            ) { OnboardingHero.cinema() }
        case .sources:
            OnboardingPageLayout(
                title: "Bring your own sources",
                subtitle: "M3U and M3U8 playlists, Jellyfin, Emby, QR codes, Files and videos from Photos."
            ) { OnboardingHero.sources() }
        case .passengers:
            OnboardingPageLayout(
                title: "Built for passengers",
                subtitle: "Video is for passengers, or for everyone while parked. Never watch while driving."
            ) {
                OnboardingHero.passengers()
            } extra: {
                acknowledgeButton
            }
        case .privacy:
            OnboardingPageLayout(
                title: "Private by design",
                subtitle: "No account and no tracking. Your sources and history stay on this iPhone."
            ) { OnboardingHero.privacy() }
        case .payOnce:
            OnboardingPageLayout(
                title: "Pay once, keep it forever",
                subtitle: "DashCast is free to use. Pro is a single purchase, never a subscription."
            ) { OnboardingHero.payOnce() }
        }
    }

    private var acknowledgeButton: some View {
        Button {
            acknowledgedSafety.toggle()
        } label: {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: acknowledgedSafety ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(acknowledgedSafety ? Color.dcAccent : Color.white.opacity(0.6))
                Text("I understand: I won't watch or use DashCast while driving.")
                    .font(DSTypography.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(DSSpacing.lg)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .strokeBorder(acknowledgedSafety ? Color.dcAccent : Color.white.opacity(0.15), lineWidth: DSStroke.regular)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Onboarding_Acknowledge")
        .accessibilityAddTraits(acknowledgedSafety ? [.isSelected] : [])
        .accessibilityHint(Text("Required to continue"))
    }

    // MARK: Actions

    private func advance() {
        guard let next = Page(rawValue: page.rawValue + 1) else { return }
        go(to: next)
    }

    private func go(to target: Page) {
        withAnimation(DSMotion.animation(DSMotion.standard, reduceMotion: reduceMotion)) {
            page = target
        }
    }

    private func finish(showPro: Bool) {
        appState.selectedTab = .home
        hasCompletedOnboarding = true
        if showPro {
            // Present after the full-screen cover has gone away. Closing the paywall continues free.
            let state = appState
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                state.showPaywall = true
            }
        }
    }
}

// MARK: - Page layout

/// Hero on top (fading into the background), then centered title + one-line subtitle, with room for the
/// bottom controls drawn by `OnboardingView`.
struct OnboardingPageLayout<Hero: View, Extra: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let hero: () -> Hero
    @ViewBuilder let extra: () -> Extra

    init(title: String, subtitle: String, @ViewBuilder hero: @escaping () -> Hero, @ViewBuilder extra: @escaping () -> Extra) {
        self.title = title
        self.subtitle = subtitle
        self.hero = hero
        self.extra = extra
    }

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            ZStack(alignment: .bottom) {
                hero()
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
                    .clipped()
                LinearGradient(colors: [.clear, Color.dcBackground], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
                    .allowsHitTesting(false)
            }
            .accessibilityHidden(true)

            VStack(spacing: DSSpacing.md) {
                Text(title)
                    .font(DSTypography.largeTitle)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(DSTypography.body)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                extra()
                    .padding(.top, DSSpacing.sm)
            }
            .padding(.horizontal, DSSpacing.xl)

            Spacer(minLength: 160) // bottom controls
        }
    }
}

extension OnboardingPageLayout where Extra == EmptyView {
    init(title: String, subtitle: String, @ViewBuilder hero: @escaping () -> Hero) {
        self.init(title: title, subtitle: subtitle, hero: hero, extra: { EmptyView() })
    }
}

// MARK: - Heroes (drawn in SwiftUI)

enum OnboardingHero {
    static func cinema() -> some View { CinemaHero() }
    static func sources() -> some View { SourcesHero() }
    static func passengers() -> some View { SymbolHero(primary: "car.side.fill", secondary: "person.2.fill", tint: .dcAccent) }
    static func privacy() -> some View { SymbolHero(primary: "lock.shield.fill", secondary: "iphone", tint: .dcInfo) }
    static func payOnce() -> some View { SymbolHero(primary: "infinity", secondary: "checkmark.seal.fill", tint: .dcPro) }
}

/// Soft glow backdrop shared by all heroes. One slow "breathing" animation; static with Reduce Motion.
private struct HeroBackdrop: View {
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    init(tint: Color) {
        self.tint = tint
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [tint.opacity(0.28), Color.dcBackground], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(RadialGradient(colors: [tint.opacity(0.55), .clear], center: .center, startRadius: 10, endRadius: 220))
                .frame(width: 440, height: 440)
                .scaleEffect(breathe ? 1.08 : 0.94)
                .offset(y: 30)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

/// A car display (wide screen in a dashboard bezel) playing video, with a phone beside it.
private struct CinemaHero: View {
    var body: some View {
        ZStack {
            HeroBackdrop(tint: .dcAccent)

            // Car display
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black)
                .frame(width: 300, height: 170)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Color.dcAccent.opacity(0.55), Color.dcInfo.opacity(0.35), Color.black],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(10)
                )
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(Color.white)
                )
                .overlay(alignment: .bottom) {
                    Capsule().fill(Color.white.opacity(0.8)).frame(width: 140, height: 4).padding(.bottom, 22)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.dcAccent.opacity(0.35), radius: 24, y: 10)
                .offset(y: -10)

            // Phone
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.dcSurface)
                .frame(width: 66, height: 128)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [Color.dcAccent.opacity(0.6), Color.black], startPoint: .top, endPoint: .bottom))
                        .padding(5)
                )
                .overlay(Image(systemName: "airplayvideo").foregroundStyle(Color.white).font(.title3))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                .offset(x: 130, y: 90)
        }
    }
}

/// Source symbols arranged around a central library stack.
private struct SourcesHero: View {
    private let symbols = ["link", "doc.fill", "server.rack", "qrcode", "photo.on.rectangle", "globe"]

    var body: some View {
        ZStack {
            HeroBackdrop(tint: .dcInfo)

            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                let angle = Double(index) / Double(symbols.count) * 2 * .pi - .pi / 2
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 64, height: 64)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                    .offset(x: cos(angle) * 125, y: sin(angle) * 125 + 20)
            }

            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(Color.dcAccent)
                .frame(width: 112, height: 112)
                .background(Color.black.opacity(0.6), in: Circle())
                .overlay(Circle().strokeBorder(Color.dcAccent.opacity(0.6), lineWidth: 2))
                .offset(y: 20)
        }
    }
}

/// A large symbol in a glowing ring with a smaller companion badge.
private struct SymbolHero: View {
    let primary: String
    let secondary: String
    let tint: Color

    var body: some View {
        ZStack {
            HeroBackdrop(tint: tint)

            ForEach(0..<3) { ring in
                Circle()
                    .strokeBorder(tint.opacity(0.35 - Double(ring) * 0.1), lineWidth: 1.5)
                    .frame(width: 170 + CGFloat(ring) * 70, height: 170 + CGFloat(ring) * 70)
            }
            .offset(y: 20)

            Image(systemName: primary)
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 150, height: 150)
                .background(Color.black.opacity(0.55), in: Circle())
                .offset(y: 20)

            Image(systemName: secondary)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 60, height: 60)
                .background(tint.opacity(0.85), in: Circle())
                .overlay(Circle().strokeBorder(Color.dcBackground, lineWidth: 4))
                .offset(x: 58, y: 78)
        }
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(AppState())
}
