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
                                    .foregroundStyle(Color.dashYellow)
                                Text("How to add to CarPlay?")
                                    .font(ThemeFonts.hudCaption(size: 13))
                                    .foregroundStyle(Color.dashYellow)
                            }
                        }

                        // Plate Widgets Section
                        plateWidgetsSection

                        // Couple Days / Anniversary Section
                        coupleDaysSection

                        // Date & Time Widgets Section
                        dateTimeSection

                        // Countdown Section
                        countdownSection

                        // Vinyl Record Section
                        vinylRecordSection

                        // Daily Quote Section
                        dailyQuoteSection

                        // 100+ Brands Section
                        brandsSection
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("Widgets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        if !appState.isProLifetimeUnlocked {
                            Button {
                                appState.showPaywall = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11))
                                    Text("PRO")
                                        .font(.system(size: 12, weight: .heavy))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(LinearGradient.dashProGoldGradient)
                                .foregroundStyle(Color.black)
                                .clipShape(Capsule())
                            }
                        }

                        Button {
                            showingCarPlayGuide = true
                        } label: {
                            Image(systemName: "questionmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.dashTextPrimary)
                                .frame(width: 32, height: 32)
                                .background(Color.dashSurface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.dashBorder, lineWidth: 1))
                        }

                        Button {
                            self.editingWidget = WidgetConfigModel()
                            self.showingEditor = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black)
                                .frame(width: 32, height: 32)
                                .background(Color.dashYellow)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { showingEditor || appState.showWidgetEditor },
                set: {
                    showingEditor = $0
                    appState.showWidgetEditor = $0
                }
            )) {
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
                        WidgetConfigModel(carBrand: "Porsche", carModelName: "911 GT3 RS", carImageName: "car_porsche_911", driverGreeting: "Welcome, Driver", showWatermark: true, stickerId: "turbo"),
                        WidgetConfigModel(carBrand: "Toyota", carModelName: "RAV4 GR Sport", carImageName: "car_toyota_rav4", driverGreeting: "Hello, Michael", showWatermark: true, stickerId: "paw"),
                        WidgetConfigModel(carBrand: "Chevrolet", carModelName: "Corvette Stingray", carImageName: "car_chevrolet_corvette", driverGreeting: "Track Ready", showWatermark: true, stickerId: "route66")
                    ]
                    PersistenceController.shared.saveWidgets(savedWidgets)
                } else {
                    savedWidgets = loaded
                }
            }
        }
    }

    private var defaultWidget: WidgetConfigModel {
        WidgetConfigModel(carBrand: "Porsche", carModelName: "911 GT3 RS", carImageName: "car_porsche_911", driverGreeting: "Welcome, Driver")
    }

    // MARK: - Plate Widgets Section

    private var plateWidgetsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Plate")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    // Plate 1: Custom Plate with Car
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.dashSurface)
                                .frame(width: 140, height: 140)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dashBorder, lineWidth: 1))

                            VStack(spacing: 10) {
                                // License Plate
                                Text("ABC-1234")
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color(white: 0.9))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.3), lineWidth: 1))

                                Image("car_porsche_911")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 110, height: 50)
                            }
                        }
                    }

                    // Plate 2: Clean Plate
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.dashSurface)
                                .frame(width: 140, height: 140)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dashBorder, lineWidth: 1))

                            Text("ABC-1234")
                                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(white: 0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.3), lineWidth: 1))
                        }
                    }

                    // Plate 3: California Style
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.dashSurface)
                                .frame(width: 140, height: 140)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dashBorder, lineWidth: 1))

                            VStack(spacing: 2) {
                                Text("California")
                                    .font(.system(size: 10, weight: .semibold, design: .serif))
                                    .foregroundStyle(Color.red)
                                Text("ACX-789")
                                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.1, green: 0.2, blue: 0.5))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Couple Days / Anniversary

    private var coupleDaysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Couple Days")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    // Sunset Couple Card
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(colors: [Color(red: 0.7, green: 0.3, blue: 0.1), Color(red: 0.15, green: 0.1, blue: 0.2)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 140, height: 140)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Together with babe")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.85))
                            Text("488 days")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        .padding(12)
                    }

                    // Holding Hands Card
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(colors: [Color(red: 0.3, green: 0.25, blue: 0.2), Color(red: 0.1, green: 0.08, blue: 0.08)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 140, height: 140)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text("1.206")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.white)
                                Text("Days")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.pink)
                            }
                        }
                        .padding(12)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Date & Time

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Date & Time")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    // Golden Gate Clock
                    ZStack(alignment: .center) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.35, blue: 0.5), Color(red: 0.1, green: 0.15, blue: 0.25)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 140, height: 140)

                        VStack(spacing: 4) {
                            Text("11:21 AM")
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .foregroundStyle(Color.white)
                            Text("Sunday")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                    }

                    // Eiffel Tower
                    ZStack(alignment: .center) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(colors: [Color(red: 0.3, green: 0.25, blue: 0.35), Color(red: 0.08, green: 0.08, blue: 0.12)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 140, height: 140)

                        VStack(spacing: 4) {
                            Text("11:21")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                            Text("PARIS · SUNDAY")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.dashYellow)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Countdown

    private var countdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Countdown")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    // Winter Countdown
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.3, blue: 0.4), Color(red: 0.08, green: 0.1, blue: 0.15)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 140, height: 140)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Winter ❄️")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white)
                                Spacer()
                            }
                            Text("In 2 months, 13 days")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                        .padding(12)
                    }

                    // Graduation Countdown
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white)
                            .frame(width: 140, height: 140)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Graduation 🎉")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.black)
                                Spacer()
                            }
                            Text("147 DAYS")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.black)
                        }
                        .padding(12)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Vinyl Record

    private var vinylRecordSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Vinyl Record")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(white: 0.95))
                            .frame(width: 140, height: 140)

                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 60, height: 60)
                                Circle()
                                    .fill(Color.dashAmber)
                                    .frame(width: 22, height: 22)
                            }

                            Text("Vinyl Sunday")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.black)

                            Text("CASSETTE CLUB")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.5))
                        }
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.dashSurface)
                            .frame(width: 140, height: 140)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.dashBorder, lineWidth: 1))

                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 60, height: 60)
                                Circle()
                                    .fill(Color.dashYellow)
                                    .frame(width: 22, height: 22)
                            }

                            Text("Midnight Crossing")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.dashTextPrimary)

                            Text("THE ANALOG FOUR")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.dashTextSecondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Daily Quote

    private var dailyQuoteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Daily Quote")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(white: 0.95))
                            .frame(width: 140, height: 140)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("1/11/26")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.purple)

                            Text("No one is keeping score at this light.")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.5))

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 9))
                                Text("Daily Refresh")
                                    .font(.system(size: 9))
                            }
                            .foregroundStyle(Color.purple)
                        }
                        .padding(12)
                    }

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.dashSurface)
                            .frame(width: 140, height: 140)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.dashBorder, lineWidth: 1))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Daily Reminder")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.dashTextPrimary)

                            Text("Quiet is a place you can drive to.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.dashTextSecondary)
                        }
                        .padding(12)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 100+ Brands Section

    private var brandsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "100+ Car Brands")

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
                                    .foregroundStyle(Color.dashYellow)
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

    private func sectionHeader(title: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
                .font(ThemeFonts.hudTitle(size: 18))
                .foregroundStyle(Color.dashTextPrimary)

            Spacer()

            Button("See all") {}
                .font(ThemeFonts.hudCaption(size: 13))
                .foregroundStyle(Color.dashYellow)
        }
        .padding(.horizontal)
    }
}
