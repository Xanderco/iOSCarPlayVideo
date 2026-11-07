import Foundation

/// Public URLs referenced from Settings, About, the paywall and the App Store listing.
/// Single source of truth: the pages live in `docs/site/` and are deployed to GitHub Pages
/// by `.github/workflows/pages.yml` (see AppStoreMedia/metadata.md §6).
public enum LegalLinks {
    public static let siteBase = URL(string: "https://xanderco.github.io/iOSCarPlayVideo/")!
    public static let privacyPolicy = URL(string: "https://xanderco.github.io/iOSCarPlayVideo/privacy.html")!
    /// Apple's standard EULA. Swap for a custom EULA URL if one is set in App Store Connect.
    public static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// App-specific terms (no content provided, user responsible for rights), which reference the Standard EULA.
    public static let appTerms = URL(string: "https://xanderco.github.io/iOSCarPlayVideo/terms.html")!
    public static let support = URL(string: "https://xanderco.github.io/iOSCarPlayVideo/support.html")!
    public static let supportEmail = "alexbh987@gmail.com"
}
