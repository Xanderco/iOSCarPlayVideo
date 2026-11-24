import SwiftUI

/// Automotive HUD badge displaying real-time rotary knob focus position and scroll acceleration velocity.
public struct CarPlayRotaryFocusBadgeView: View {
    @ObservedObject var rotaryService = CarPlayRotaryNavigationService.shared
    public var isCompact: Bool

    public init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }

    public var body: some View {
        if isCompact {
            compactPill
        } else {
            expandedPill
        }
    }

    private var compactPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dcAccent)

            if rotaryService.currentVelocityMultiplier > 1 {
                Text("\(rotaryService.currentVelocityMultiplier)x")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.dcAccent)
            } else {
                Text("ROTARY")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.dcTextSecondary)
                    .tracking(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.dcSurface.opacity(0.85))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.dcAccent.opacity(0.4), lineWidth: 1)
        )
    }

    private var expandedPill: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.dcAccent.opacity(0.2))
                    .frame(width: 22, height: 22)
                Image(systemName: "circle.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dcAccent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("ROTARY FOCUS")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color.dcTextTertiary)
                    .tracking(1)

                HStack(spacing: 4) {
                    if rotaryService.itemCount > 0 {
                        Text("Item \(rotaryService.focusedIndex + 1) of \(rotaryService.itemCount)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.dcTextPrimary)
                    } else {
                        Text(rotaryService.statusLabel)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.dcTextPrimary)
                    }

                    if rotaryService.currentVelocityMultiplier > 1 {
                        Text("· \(rotaryService.currentVelocityMultiplier)x Stride")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.dcAccent)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.dcSurfaceRaised.opacity(0.92))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.dcAccent.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)
    }
}
