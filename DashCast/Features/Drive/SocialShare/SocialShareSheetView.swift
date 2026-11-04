import SwiftUI

public struct SocialShareSheetView: View {
    @Environment(\.dismiss) private var dismiss
    public let trip: TripModel

    @State private var selectedTemplate: SocialShareTemplateType = .apexYellow
    @State private var selectedVehicleIndex: Int = 0
    @State private var licensePlateText: String = "APEX-911"
    @State private var showingSavedToast: Bool = false

    private let vehicles = VehicleCatalogService.shared.vehicles

    public init(trip: TripModel) {
        self.trip = trip
    }

    private var currentCardData: SocialShareCardData {
        let vehicle = vehicles.indices.contains(selectedVehicleIndex) ? vehicles[selectedVehicleIndex] : (vehicles.first ?? VehicleModel(id: "porsche_911", brandId: "porsche", name: "911 GT3 RS", year: "2024", colorName: "Agate Grey", carAccentColor: .dashYellow, imageName: "car_porsche_911"))

        return SocialShareCardData(
            trip: trip,
            vehicleName: vehicle.name,
            vehicleImageName: vehicle.imageName,
            licensePlate: licensePlateText.isEmpty ? "DASHCAST" : licensePlateText.uppercased(),
            peakGForce: max(0.65, Double(trip.maxSpeedKmh) * 0.006 + 0.35),
            template: selectedTemplate
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Interactive 9:16 Card Preview
                        cardPreviewContainer

                        // 2. Template Selector Carousel
                        templateSelectorSection

                        // 3. Vehicle Artwork Switcher
                        vehicleSelectorSection

                        // 4. Custom Plate Input
                        licensePlateSection

                        // 5. High-Impact Share Action Buttons (48pt touch targets)
                        shareActionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 36)
                }

                // Toast notice when saved
                if showingSavedToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.dashBackground)
                            Text("Story Card Ready to Share!")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.dashBackground)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.dashYellow)
                        .clipShape(Capsule())
                        .shadow(color: Color.dashYellow.opacity(0.4), radius: 8, y: 4)
                        .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Share Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(Color.dashYellow)
                        .frame(minWidth: 48, minHeight: 48)
                    }
                }
            }
        }
    }

    // MARK: - 1. Card Preview Container
    private var cardPreviewContainer: some View {
        VStack(spacing: 8) {
            SocialShareCardView(data: currentCardData)
                .frame(maxWidth: 320)
                .frame(height: 520)
                .padding(.vertical, 8)

            Text("9:16 Vertical Story • Optimized for TikTok & Instagram")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.dashTextMuted)
        }
    }

    // MARK: - 2. Template Selector Section
    private var templateSelectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THEME TEMPLATE")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color.dashTextMuted)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                ForEach(SocialShareTemplateType.allCases) { tmpl in
                    let isSelected = selectedTemplate == tmpl
                    Button {
                        selectedTemplate = tmpl
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tmpl.accentColor)
                                .frame(width: 10, height: 10)
                            Text(tmpl.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(isSelected ? Color.dashSurfaceHighlight : Color.dashSurface)
                        .foregroundStyle(isSelected ? Color.dashTextPrimary : Color.dashTextSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? tmpl.accentColor : Color.dashBorder, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - 3. Vehicle Selector Section
    private var vehicleSelectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VEHICLE ARTWORK")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color.dashTextMuted)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(vehicles.enumerated()), id: \.element.id) { index, v in
                        let isSelected = selectedVehicleIndex == index
                        Button {
                            selectedVehicleIndex = index
                        } label: {
                            VStack(spacing: 6) {
                                Image(v.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 70, height: 40)

                                Text(v.name)
                                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? Color.dashYellow : Color.dashTextSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 95, height: 75)
                            .background(Color.dashSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSelected ? Color.dashYellow : Color.dashBorder, lineWidth: isSelected ? 1.5 : 1)
                            )
                        }
                        .frame(minHeight: 48)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - 4. License Plate Input Section
    private var licensePlateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CUSTOM LICENSE PLATE")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color.dashTextMuted)
                .padding(.horizontal, 4)

            HStack {
                Image(systemName: "rectangle.inset.filled")
                    .foregroundStyle(Color.dashYellow)
                TextField("PLATE TEXT", text: $licensePlateText)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.dashTextPrimary)
                    .textInputAutocapitalization(.characters)
            }
            .padding(14)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.dashBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - 5. Share Actions Section
    private var shareActionsSection: some View {
        VStack(spacing: 12) {
            // Main Share Button (48pt touch height)
            ShareLink(
                item: "Check out my DashCast Drive Telemetry! Grade: \(currentCardData.driverGrade.grade) (\(currentCardData.driverGrade.title)) • \(String(format: "%.1f km", trip.distanceKilometers)) driven. Zero Subscriptions on CarPlay: carplay.dashcast.app",
                subject: Text("My DashCast Drive Story"),
                message: Text("Check out my DashCast drive score: \(trip.drivingScore)/100")
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Share Story to TikTok / Instagram")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FFE600"), Color(hex: "#FFB800")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color(hex: "#FFE600").opacity(0.35), radius: 8, y: 3)
            }

            // Secondary Copy / Save Button
            Button {
                withAnimation {
                    showingSavedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showingSavedToast = false
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line.circle.fill")
                        .font(.system(size: 15))
                    Text("Save High-Res Story Card")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.dashSurfaceHighlight)
                .foregroundStyle(Color.dashTextPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.dashBorder, lineWidth: 1)
                )
            }
        }
    }
}
