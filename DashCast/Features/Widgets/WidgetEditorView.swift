import SwiftUI

public struct WidgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config: WidgetConfigModel
    @State private var selectedBrandIndex = 0
    @State private var trimTime: Double = 0.0
    public var onSave: (WidgetConfigModel) -> Void

    private let catalog = VehicleCatalogService.shared

    public init(config: WidgetConfigModel = WidgetConfigModel(), onSave: @escaping (WidgetConfigModel) -> Void) {
        self._config = State(initialValue: config)
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Live CarPlay Mockup Preview
                        VStack(spacing: 8) {
                            CarPlayDashboardMockupView(config: config)
                                .padding(.horizontal)

                            Text("CarPlay Display Preview")
                                .font(ThemeFonts.hudCaption(size: 12))
                                .foregroundStyle(Color.dashTextMuted)
                        }

                        // Driver Greeting Customizer
                        AutomotiveCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("DRIVER GREETING")
                                    .font(ThemeFonts.hudCaption(size: 11))
                                    .foregroundStyle(Color.dashTextMuted)
                                    .tracking(1.0)

                                TextField("e.g. Welcome, Driver", text: $config.driverGreeting)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                    .padding(10)
                                    .background(Color.dashSurfaceHighlight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal)

                        // Car Brand & Model Selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Car Model")
                                .font(ThemeFonts.hudTitle(size: 18))
                                .foregroundStyle(Color.dashTextPrimary)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(catalog.vehicles) { vehicle in
                                        let isSelected = config.carModelName == vehicle.name
                                        Button {
                                            config.carModelName = vehicle.name
                                            config.carImageName = vehicle.imageName
                                            if let brand = catalog.brands.first(where: { $0.id == vehicle.brandId }) {
                                                config.carBrand = brand.name
                                            }
                                        } label: {
                                            VStack(spacing: 8) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .fill(Color.dashSurface)
                                                        .frame(width: 120, height: 80)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 14)
                                                                .stroke(isSelected ? Color.dashYellow : Color.dashBorder, lineWidth: isSelected ? 3 : 1)
                                                        )

                                                    if let uiImage = UIImage(named: vehicle.imageName) ?? UIImage(contentsOfFile: Bundle.main.path(forResource: vehicle.imageName, ofType: "png") ?? "") {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(height: 52)
                                                            .padding(4)
                                                    } else {
                                                        Image(systemName: "car.side.fill")
                                                            .font(.system(size: 32))
                                                            .foregroundStyle(vehicle.carAccentColor)
                                                    }
                                                }

                                                Text(vehicle.name)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(isSelected ? Color.dashYellow : Color.dashTextPrimary)
                                                    .lineLimit(1)
                                            }
                                            .frame(width: 120)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Brand Watermark Toggle
                        AutomotiveCard {
                            Toggle(isOn: $config.showWatermark) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Brand Watermark")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.dashTextPrimary)
                                    Text("Display \(config.carBrand) logo watermark in background")
                                        .font(ThemeFonts.hudCaption(size: 12))
                                        .foregroundStyle(Color.dashTextSecondary)
                                }
                            }
                            .tint(.dashYellow)
                        }
                        .padding(.horizontal)

                        // Stickers Selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sticker Badge")
                                .font(ThemeFonts.hudTitle(size: 18))
                                .foregroundStyle(Color.dashTextPrimary)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(catalog.stickers) { sticker in
                                        let isSelected = config.stickerId == sticker.id
                                        Button {
                                            if config.stickerId == sticker.id {
                                                config.stickerId = nil
                                            } else {
                                                config.stickerId = sticker.id
                                            }
                                        } label: {
                                            VStack(spacing: 6) {
                                                ZStack {
                                                    Circle()
                                                        .fill(isSelected ? Color.dashYellow.opacity(0.2) : Color.dashSurface)
                                                        .frame(width: 50, height: 50)
                                                        .overlay(
                                                            Circle()
                                                                .stroke(isSelected ? Color.dashYellow : Color.dashBorder, lineWidth: 2)
                                                        )

                                                    Image(systemName: sticker.icon)
                                                        .font(.system(size: 20))
                                                        .foregroundStyle(isSelected ? Color.dashYellow : Color.dashGold)
                                                }

                                                Text(sticker.title)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(Color.dashTextSecondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Live Video Trimmer (for Live Wallpapers)
                        VideoTrimmerView(trimStartTime: $trimTime)
                            .padding(.horizontal)

                        // Add to My Widgets CTA
                        GlowButton(title: "Add to My Widgets", iconName: "plus.circle.fill", gradient: .dashAccentGradient) {
                            onSave(config)
                            dismiss()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 10)
                }
            }
            .navigationTitle("Edit Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.dashTextSecondary)
                }
            }
        }
    }
}
