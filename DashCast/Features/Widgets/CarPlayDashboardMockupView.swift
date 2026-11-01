import SwiftUI

public struct CarPlayDashboardMockupView: View {
    public let config: WidgetConfigModel

    public init(config: WidgetConfigModel) {
        self.config = config
    }

    public var body: some View {
        ZStack {
            // Dashboard Display Bezel (Curved automotive car screen)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.dashBorder, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.6), radius: 14, y: 6)

            HStack(spacing: 0) {
                // CarPlay Left Sidebar
                VStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text("9:41")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                        HStack(spacing: 2) {
                            Image(systemName: "cellularbars")
                            Image(systemName: "wifi")
                        }
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                    }

                    Spacer()

                    Image(systemName: "map.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dashGreen)
                        .padding(6)
                        .background(Color.dashSurfaceHighlight)
                        .clipShape(Circle())

                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dashRed)
                        .padding(6)
                        .background(Color.dashSurfaceHighlight)
                        .clipShape(Circle())

                    Image(systemName: "phone.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dashCyan)
                        .padding(6)
                        .background(Color.dashSurfaceHighlight)
                        .clipShape(Circle())

                    Spacer()

                    Image(systemName: "square")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dashTextMuted)
                }
                .frame(width: 44)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.3))

                // CarPlay Screen Content: Dual widgets
                HStack(spacing: 10) {
                    // Widget 1: Car Widget Card
                    carWidgetTile
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Widget 2: Countdown / Info Card
                    countdownWidgetTile
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(10)
            }
        }
        .frame(height: 180)
    }

    private var carWidgetTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color.dashSurfaceHighlight, Color.dashSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Brand Watermark in background if enabled
            if config.showWatermark {
                Text(config.carBrand.uppercased())
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.08))
                    .tracking(2.0)
                    .offset(y: -24)
            }

            VStack(spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("August")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.dashTextSecondary)
                        Text("03")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.dashTextPrimary)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(Color.dashGold)
                        Text("72°F")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)

                // Real Car illustration
                ZStack {
                    if let uiImage = loadCarUIImage(name: config.carImageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                            .shadow(color: Color.black.opacity(0.6), radius: 6, y: 3)
                    } else {
                        Image(systemName: "car.side.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 48)
                            .foregroundStyle(Color.dashCyan)
                    }

                    if let stickerId = config.stickerId {
                        Image(systemName: stickerIcon(for: stickerId))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.dashGold)
                            .offset(x: 24, y: -16)
                    }
                }

                Spacer()

                HStack {
                    Text(config.driverGreeting)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(config.carModelName)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.dashCyan)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
    }

    private var countdownWidgetTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color.dashRed.opacity(0.85), Color.dashBlue.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 2) {
                Text(config.countdownTitle ?? "10")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("DAYS LEFT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(1.5)
            }
        }
    }

    private func stickerIcon(for id: String) -> String {
        VehicleCatalogService.shared.stickers.first(where: { $0.id == id })?.icon ?? "sparkle"
    }

    private func loadCarUIImage(name: String) -> UIImage? {
        if let img = UIImage(named: name) { return img }
        if let path = Bundle.main.path(forResource: name, ofType: "png") {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
}
