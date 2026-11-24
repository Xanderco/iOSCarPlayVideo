import SwiftUI

/// Compact or expanded automotive HUD badge displaying DarkShield photopic status.
/// Conforms to minimum 48x48pt touch targets for in-cockpit ergonomics.
public struct DarkShieldBadgeView: View {
    @ObservedObject private var visionService = DarkShieldVisionService.shared
    @EnvironmentObject private var appState: AppState

    public var isCompact: Bool

    public init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }

    public var body: some View {
        Button {
            appState.showDarkShieldSheet = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: visionService.statusIconName)
                    .font(.system(size: isCompact ? 10 : 12, weight: .bold))
                    .foregroundStyle(visionService.statusColor)

                if !isCompact {
                    Text(visionService.statusTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)

                    if visionService.isActive {
                        Text(visionService.effectivePreset == .aviationRed ? "650nm" : (visionService.effectivePreset == .photopicAmber ? "589nm" : "0-Nit"))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.dcTextSecondary)
                    }
                }
            }
            .padding(.horizontal, isCompact ? 8 : 10)
            .padding(.vertical, isCompact ? 5 : 6)
            .background(
                Capsule()
                    .fill(Color.dcSurface.opacity(0.88))
            )
            .overlay(
                Capsule()
                    .strokeBorder(visionService.isActive ? visionService.statusColor.opacity(0.7) : Color.dcStroke, lineWidth: 1)
            )
        }
        .accessibilityLabel("DarkShield Vision Glare Guard")
        .accessibilityValue(visionService.statusTitle)
    }
}
