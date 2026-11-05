import Foundation

/// Public URLs referenced from Settings, About, the paywall and the App Store listing.
/// Replace the placeholder dashcast.app pages with the real hosted pages before submission
/// (see AppStoreMedia/metadata.md and Docs/AppReview-checklist.md).
public enum LegalLinks {
    public static let privacyPolicy = URL(string: "https://dashcast.app/privacy")!
    /// Apple's standard EULA. Swap for a custom EULA URL if one is set in App Store Connect.
    public static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    public static let support = URL(string: "https://dashcast.app/support")!
    public static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
}
