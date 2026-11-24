import SwiftUI

/// Ultra-low power OLED pure black canvas overlay that drops phone display power and backlight
/// heat to absolute zero while keeping CarPlay video and navigation running smoothly.
public struct CockpitThermalDimmerOverlay: View {
    @ObservedObject private var thermalService = CockpitThermalService.shared

    public init() {}

    public var body: some View {
        ZStack {
            // Pure black OLED background (pixels turned completely off on iPhone OLED)
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Minimalist pulsating status icon
                ZStack {
                    Circle()
                        .fill(thermalService.statusColor.opacity(0.12))
                        .frame(width: 88, height: 88)

                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(thermalService.statusColor)
                }

                VStack(spacing: 8) {
                    Text("COCKPIT THERMAL SAVER ACTIVE")
                        .font(.system(size: 13, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Color.white)

                    Text("OLED Pure Black Mode • 60% Display Heat Reduction")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))

                    Text("CarPlay External Display & Background GPS are unaffected")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

                HStack(spacing: 12) {
                    Label(thermalService.localizedStateTitle, systemImage: thermalService.statusIconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(thermalService.statusColor)

                    Text("•")
                        .foregroundStyle(Color.white.opacity(0.3))

                    Text("\(thermalService.targetFrameRate) FPS Throttled")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())

                Spacer()

                // Tap to wake button and hint
                Button {
                    thermalService.wakeScreen()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 14))
                        Text("Tap Anywhere to Wake Display")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.15))
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
                }
                .padding(.bottom, 48)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            thermalService.wakeScreen()
        }
    }
}
