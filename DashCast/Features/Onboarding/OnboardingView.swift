import SwiftUI

/// First-run flow: Welcome → Passenger safety (must be acknowledged) → Get started.
/// Shown once; can be replayed from Settings › Help & About.
public struct OnboardingView: View {
    /// Completing onboarding means the passenger-only notice was acknowledged, so both share one key.
    public static let completedKey = PassengerSafetyNotice.acceptedKey

    /// Skip for automated runs: screenshots and UI tests (`PassengerSafetyNotice.shouldSkip`),
    /// unit-test hosts, and `-skipOnboarding`.
    public static var shouldSkipForLaunch: Bool {
        let info = ProcessInfo.processInfo
        if PassengerSafetyNotice.shouldSkip { return true }
        if info.environment["XCTestConfigurationFilePath"] != nil { return true }
        return info.arguments.contains("-skipOnboarding")
    }

    private enum Page: Int, CaseIterable {
        case welcome, safety, start
    }

    @EnvironmentObject private var appState: AppState
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page: Page = .welcome
    @State private var acknowledgedSafety = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $page) {
                welcomePage.tag(Page.welcome)
                safetyPage.tag(Page.safety)
                startPage.tag(Page.start)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // The safety page cannot be swiped past until it is acknowledged.
            .onChange(of: page) { oldValue, newValue in
                if newValue == .start && !acknowledgedSafety {
                    page = .safety
                }
            }

            footer
        }
        .background(Color.dcBackground.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            pageDots
            Spacer()
            if page == .welcome {
                Button("Skip") { go(to: .safety) }
                    .font(DSTypography.headline)
                    .foregroundStyle(Color.dcTextSecondary)
                    .frame(minHeight: DSLayout.minTapTarget)
            }
        }
        .padding(.horizontal, DSSpacing.screenGutter)
        .padding(.top, DSSpacing.sm)
        .frame(minHeight: DSLayout.minTapTarget)
    }

    private var pageDots: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(Page.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item == page ? Color.dcAccent : Color.dcSurfaceRaised)
                    .frame(width: item == page ? 20 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(page.rawValue + 1) of \(Page.allCases.count)"))
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: DSSpacing.sm) {
            switch page {
            case .welcome:
                PrimaryButton("Continue") { go(to: .safety) }
            case .safety:
                PrimaryButton("I Understand") { go(to: .start) }
                    .disabled(!acknowledgedSafety)
                    .opacity(acknowledgedSafety ? 1 : 0.5)
            case .start:
                PrimaryButton("Add Your First Source", systemImage: "plus") {
                    finish(openLibrary: true)
                }
                PrimaryButton("Look Around First", kind: .tertiary) {
                    finish(openLibrary: false)
                }
            }
        }
        .padding(.horizontal, DSSpacing.screenGutter)
        .padding(.bottom, DSSpacing.lg)
    }

    // MARK: Pages

    private var welcomePage: some View {
        pageScaffold(
            systemImage: "play.rectangle.on.rectangle.fill",
            title: "Your videos, on the bigger screen",
            message: "Play your playlists, channels and videos on iPhone, then send them to the car display or any AirPlay screen."
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                featureLine("square.stack.fill", "Bring your own M3U playlists, links and files")
                featureLine("airplayvideo", "Cast with AirPlay or mirror to a connected display")
                featureLine("lock.fill", "No account. Everything stays on this iPhone")
            }
        }
    }

    private var safetyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.dcWarning)
                        .accessibilityHidden(true)
                    Text("For passengers only")
                        .font(DSTypography.title)
                        .foregroundStyle(Color.dcTextPrimary)
                    Text("Please read this before your first trip.")
                        .font(DSTypography.body)
                        .foregroundStyle(Color.dcTextSecondary)
                }

                SafetyNoticeContent()

                Toggle(isOn: $acknowledgedSafety) {
                    Text("I won't watch or operate DashCast while driving.")
                        .font(DSTypography.headline)
                        .foregroundStyle(Color.dcTextPrimary)
                }
                .tint(Color.dcAccent)
                .padding(DSSpacing.lg)
                .background(Color.dcSurface, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            }
            .padding(.horizontal, DSSpacing.screenGutter)
            .padding(.vertical, DSSpacing.xl)
        }
    }

    private var startPage: some View {
        pageScaffold(
            systemImage: "plus.rectangle.on.folder.fill",
            title: "Add something to watch",
            message: "Paste a playlist link, open a file, or pick videos from this iPhone. You can add more sources at any time from Library."
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                featureLine("link", "Playlist or stream link (M3U, M3U8, HLS)")
                featureLine("doc.fill", "Playlist file from Files")
                featureLine("iphone", "Videos already on this iPhone")
            }
        }
    }

    // MARK: Building blocks

    private func pageScaffold<Extra: View>(
        systemImage: String,
        title: String,
        message: String,
        @ViewBuilder extra: () -> Extra
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                ZStack {
                    Circle()
                        .fill(Color.dcAccentSoft)
                        .frame(width: 96, height: 96)
                    Image(systemName: systemImage)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.dcAccent)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text(title)
                        .font(DSTypography.title)
                        .foregroundStyle(Color.dcTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message)
                        .font(DSTypography.body)
                        .foregroundStyle(Color.dcTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                extra()
            }
            .padding(.horizontal, DSSpacing.screenGutter)
            .padding(.vertical, DSSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func featureLine(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.dcAccent)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .font(DSTypography.callout)
                .foregroundStyle(Color.dcTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    private func go(to target: Page) {
        withAnimation(DSMotion.animation(DSMotion.standard, reduceMotion: reduceMotion)) {
            page = target
        }
    }

    private func finish(openLibrary: Bool) {
        appState.selectedTab = openLibrary ? .library : .home
        hasCompletedOnboarding = true
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
