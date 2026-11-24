import SwiftUI

/// Compact HUD badge representing current device thermal status and rendering throttling level.
/// Designed for high-contrast automotive visibility and 48x48pt in-car touch targets.
public struct CockpitThermalBadgeView: View {
    @ObservedObject private var thermalService = CockpitThermalService.shared
    @EnvironmentObject private var appState: AppState

    public var isCompact: Bool

    public init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }

    public var body: some View {
        Button {
            appState.showThermalSheet = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: thermalService.statusIconName)
                    .font(.system(size: isCompact ? 10 : 12, weight: .bold))
                    .foregroundStyle(thermalService.statusColor)

                if !isCompact {
                    Text(thermalService.localizedStateTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.dcTextPrimary)

                    Text("\(thermalService.targetFrameRate) FPS")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.dcTextSecondary)
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
                    .strokeBorder(thermalService.isThrottlingActive ? thermalService.statusColor.opacity(0.7) : Color.dcStroke, lineWidth: 1)
            )
        }
        .accessibilityLabel("Cockpit Thermal Protection")
        .accessibilityValue(String(describing: thermalService.effectiveThermalState))
    }
}
