import SwiftUI

public struct WidgetsHomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var savedWidgets: [WidgetConfigModel] = []
    @State private var showingEditor: Bool = false
    @State private var editingWidget: WidgetConfigModel?
    @State private var showingCarPlayGuide: Bool = false

    private let catalog = VehicleCatalogService.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Top CarPlay Live Mockup
                        let activeWidget = savedWidgets.first ?? defaultWidget
                        CarPlayDashboardMockupView(config: activeWidget)
                            .padding(.horizontal)

                        // Help Link: How to add to CarPlay?
                        Button {
                            showingCarPlayGuide = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundStyle(Color.dashCyan)
                                Text("How to add to CarPlay?")
                                    .font(ThemeFonts.hudCaption(size: 13))
                                    .foregroundStyle(Color.dashCyan)
                            }
                        }

                        // My Widgets Section
                        myWidgetsSection

                        // 100+ Brands Section
                        brandsSection

                        // Live Wallpaper Video Loops Showcase
                        liveWallpapersSection
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("CarDash Widgets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.editingWidget = WidgetConfigModel()
                        self.showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.dashCyan)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                WidgetEditorView(config: editingWidget ?? WidgetConfigModel()) { saved in
                    savedWidgets.insert(saved, at: 0)
                    PersistenceController.shared.saveWidgets(savedWidgets)
                }
            }
            .alert("Add Widgets to CarPlay", isPresented: $showingCarPlayGuide) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("1. Connect your iPhone to your CarPlay vehicle.\n2. On your car's display, swipe to the Dashboard view.\n3. DashCast widgets will automatically reflect your customized vehicle model, countdowns, and live status.")
            }
            .onAppear {
                let loaded = PersistenceController.shared.loadWidgets()
                if loaded.isEmpty {
                    savedWidgets = [
                        WidgetConfigModel(carBrand: "Toyota", carModelName: "RAV4 Prime", driverGreeting: "Welcome, Driver", showWatermark: true, stickerId: "paw"),
                        WidgetConfigModel(carBrand: "Chevrolet", carModelName: "Corvette Z06", driverGreeting: "Hello, Michael", showWatermark: true, stickerId: "turbo"),
                        WidgetConfigModel(carBrand: "Ford", carModelName: "Mustang Dark Horse", driverGreeting: "Track Ready", showWatermark: true, stickerId: "route66")
                    ]
                    PersistenceController.shared.saveWidgets(savedWidgets)
                } else {
                    savedWidgets = loaded
                }
            }
        }
    }

    private var defaultWidget: WidgetConfigModel {
        WidgetConfigModel(carBrand: "Toyota", carModelName: "GR Supra", driverGreeting: "Welcome, Driver")
    }

    private var myWidgetsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("My Widgets")
                    .font(ThemeFonts.hudTitle(size: 18))
                    .foregroundStyle(Color.dashTextPrimary)

                Spacer()

                Button("See all") {}
                    .font(ThemeFonts.hudCaption(size: 13))
                    .foregroundStyle(Color.dashCyan)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(savedWidgets) { widget in
                        Button {
                            self.editingWidget = widget
                            self.showingEditor = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.dashSurface)
                                        .frame(width: 140, height: 110)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.dashBorder, lineWidth: 1)
                                        )

                                    VStack(spacing: 6) {
                                        Text(widget.carBrand.uppercased())
                                            .font(.system(size: 11, weight: .black))
                                            .foregroundStyle(Color.dashTextMuted)

                                        Image(systemName: "car.side.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(Color.dashCyan)

                                        Text(widget.driverGreeting)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(Color.dashTextSecondary)
                                    }
                                }

                                Text(widget.carModelName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                    .lineLimit(1)
                            }
                            .frame(width: 140)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var brandsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("100+ Car Brands")
                    .font(ThemeFonts.hudTitle(size: 18))
                    .foregroundStyle(Color.dashTextPrimary)

                Spacer()

                Button("See all") {}
                    .font(ThemeFonts.hudCaption(size: 13))
                    .foregroundStyle(Color.dashCyan)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(catalog.brands) { brand in
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.dashSurface)
                                    .frame(width: 90, height: 75)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.dashBorder, lineWidth: 1)
                                    )

                                Image(systemName: "steeringwheel")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Color.dashGold)
                            }

                            Text(brand.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.dashTextPrimary)
                                .lineLimit(1)
                        }
                        .frame(width: 90)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var liveWallpapersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Live Wallpaper Themes")
                .font(ThemeFonts.hudTitle(size: 18))
                .foregroundStyle(Color.dashTextPrimary)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                themeCard(title: "Cyber Neon", subtitle: "Animated LED drift loop", icon: "sparkles")
                themeCard(title: "Retro 80s", subtitle: "Pixel synthwave car display", icon: "tv.fill")
                themeCard(title: "Track telemetry", subtitle: "GT3 lap timer style", icon: "stopwatch.fill")
                themeCard(title: "Custom Photo/Loop", subtitle: "Trim your own 3s clip", icon: "video.fill")
            }
            .padding(.horizontal)
        }
    }

    private func themeCard(title: String, subtitle: String, icon: String) -> some View {
        AutomotiveCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.dashCyan)

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.dashTextPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dashTextSecondary)
            }
        }
    }
}
