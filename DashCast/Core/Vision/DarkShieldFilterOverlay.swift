import SwiftUI

/// Real-time photopic color matrix filter and windshield reflection suppression overlay.
/// Placed directly over video playback canvases and browser viewports.
public struct DarkShieldFilterOverlay: View {
    @ObservedObject private var visionService = DarkShieldVisionService.shared
    public var isWebBrowser: Bool

    public init(isWebBrowser: Bool = false) {
        self.isWebBrowser = isWebBrowser
    }

    public var body: some View {
        if visionService.isActive || (isWebBrowser && visionService.isInvertWhiteBackgroundsEnabled) {
            ZStack {
                // Color matrix tint overlay with blend mode
                visionService.overlayTintColor
                    .blendMode(visionService.overlayBlendMode)

                // Optional Windshield reflection suppressor:
                // Soft gradient darkening at the top 25% of viewport to prevent windshield mirror bounce
                if visionService.isWindshieldReflectionSuppressed {
                    VStack {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.40 * visionService.glareReductionLevel),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 50)

                        Spacer()
                    }
                }
            }
            .allowsHitTesting(false)
            .transition(.opacity.animation(.easeInOut(duration: 0.35)))
        }
    }
}
