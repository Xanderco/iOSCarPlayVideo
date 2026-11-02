import SwiftUI

public struct WidgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config: WidgetConfigModel
    @State private var selectedPositionTarget: String = "Car"
    public var onSave: (WidgetConfigModel) -> Void

    private let catalog = VehicleCatalogService.shared

    public init(config: WidgetConfigModel = WidgetConfigModel(), onSave: @escaping (WidgetConfigModel) -> Void) {
        self._config = State(initialValue: config)
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1:1 Widget Preview Card
                        widgetPreviewCard

                        // 1:1 Adjust Position Section with Sliders
                        adjustPositionSection

                        // Vehicle Model & Brand Selection
                        vehicleModelSection

                        // Sticker Selector
                        stickerSection

                        // Clear space for sticky bottom button
                        Color.clear.frame(height: 80)
                    }
                    .padding(.top, 14)
                }

                // Sticky "Add to My Widgets" Button
                addToMyWidgetsButton
            }
            .navigationTitle("Edit widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.dashYellow)
                    }
                }
            }
        }
    }

    // MARK: - Widget Preview Card (Matching Edit widgets on the same app.jpeg)

    private var widgetPreviewCard: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                // Background dark surface
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                    .frame(width: 260, height: 260)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 12, y: 6)

                // Background Brand Watermark
                if config.showWatermark {
                    Text(config.carBrand.uppercased())
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.06))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 24)
                }

                // Car Render with Scale & Offsets
                ZStack {
                    Image(config.carImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200 * config.carScale)
                        .offset(x: config.carHorizontalOffset, y: config.carVerticalOffset)
                        .shadow(color: Color.black.opacity(0.6), radius: 8, y: 4)

                    // Sticker overlay with red x close button
                    if let stickerId = config.stickerId {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.dashYellow.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                .frame(width: 60, height: 60)

                            Image(systemName: stickerIcon(for: stickerId))
                                .font(.system(size: 28))
                                .foregroundStyle(Color.dashYellow)
                                .frame(width: 60, height: 60)

                            Button {
                                config.stickerId = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.dashRed)
                                    .background(Color.white.clipShape(Circle()))
                                    .offset(x: 6, y: -6)
                            }
                        }
                        .offset(x: config.carHorizontalOffset + 30, y: config.carVerticalOffset - 10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Labels (Greeting + Location/Weather)
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.driverGreeting)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                        Text("Barranquilla · 33°, Cloudy")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.dashTextSecondary)
                }
                .padding(16)
            }
            .frame(width: 260, height: 260)

            Button("Preview") {}
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dashYellow)
        }
    }

    // MARK: - Adjust Position Sliders

    private var adjustPositionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adjust Position")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.dashTextPrimary)
                .padding(.horizontal, 16)

            // Segmented Target Picker (Logo vs Car)
            Picker("Target", selection: $selectedPositionTarget) {
                Text("Logo").tag("Logo")
                Text("Car").tag("Car")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            VStack(spacing: 12) {
                // Size Slider
                sliderRow(
                    title: "Size",
                    value: $config.carScale,
                    range: 0.6...1.6,
                    leadingIcon: "minus",
                    trailingIcon: "plus"
                )

                // Vertical Slider
                sliderRow(
                    title: "Vertical",
                    value: $config.carVerticalOffset,
                    range: -50...50,
                    leadingIcon: "arrow.up",
                    trailingIcon: "arrow.down"
                )

                // Horizontal Slider
                sliderRow(
                    title: "Horizontal",
                    value: $config.carHorizontalOffset,
                    range: -50...50,
                    leadingIcon: "arrow.left",
                    trailingIcon: "arrow.right"
                )
            }
            .padding(16)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.dashBorder, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        leadingIcon: String,
        trailingIcon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.dashTextSecondary)

            HStack(spacing: 12) {
                Image(systemName: leadingIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextMuted)
                    .frame(width: 14)

                Slider(value: value, in: range)
                    .tint(Color.dashYellow)

                Image(systemName: trailingIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextMuted)
                    .frame(width: 14)
            }
        }
    }

    // MARK: - Vehicle Model Section

    private var vehicleModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Vehicle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.dashTextPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(catalog.vehicles) { vehicle in
                        let isSelected = config.carModelName == vehicle.name
                        Button {
                            config.carBrand = vehicle.brandId.capitalized
                            config.carModelName = vehicle.name
                            config.carImageName = vehicle.imageName
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(isSelected ? Color.dashYellow.opacity(0.15) : Color.dashSurface)
                                        .frame(width: 110, height: 75)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(isSelected ? Color.dashYellow : Color.dashBorder, lineWidth: isSelected ? 2 : 1)
                                        )

                                    Image(vehicle.imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 90, height: 50)
                                }

                                Text(vehicle.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(isSelected ? Color.dashYellow : Color.dashTextPrimary)
                                    .lineLimit(1)
                            }
                            .frame(width: 110)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Sticker Section

    private var stickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Badge Sticker")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.dashTextPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(catalog.stickers) { sticker in
                        let isSelected = config.stickerId == sticker.id
                        Button {
                            if isSelected {
                                config.stickerId = nil
                            } else {
                                config.stickerId = sticker.id
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? Color.dashYellow.opacity(0.2) : Color.dashSurface)
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Circle()
                                                .stroke(isSelected ? Color.dashYellow : Color.dashBorder, lineWidth: 2)
                                        )

                                    Image(systemName: sticker.icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(isSelected ? Color.dashYellow : Color.dashGold)
                                }

                                Text(sticker.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.dashTextSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Sticky Bottom Button

    private var addToMyWidgetsButton: some View {
        Button {
            onSave(config)
            dismiss()
        } label: {
            Text("Add to My Widgets")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(LinearGradient.dashAccentGradient)
                .clipShape(Capsule())
                .shadow(color: Color.dashYellow.opacity(0.35), radius: 10, y: 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func stickerIcon(for id: String) -> String {
        catalog.stickers.first(where: { $0.id == id })?.icon ?? "flag.checkered"
    }
}
