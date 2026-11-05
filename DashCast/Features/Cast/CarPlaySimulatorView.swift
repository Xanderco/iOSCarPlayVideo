import SwiftUI

public struct CarPlaySimulatorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var playerService = VideoPlayerService.shared

    public enum CarPlayScreenMode: String, CaseIterable, Identifiable {
        case appLaunched = "App in CarPlay"
        case dashboard = "CarPlay Dashboard"
        case appMenu = "CarPlay Home Menu"

        public var id: String { rawValue }
    }

    @State private var activeMode: CarPlayScreenMode = .appLaunched
    @State private var selectedCarPlayTab: String = "Cast"

    public init() {}

    private var activeWidget: WidgetConfigModel {
        PersistenceController.shared.loadWidgets().first ?? WidgetConfigModel(
            carBrand: "Porsche",
            carModelName: "911 GT3 RS",
            carImageName: "car_porsche_911",
            driverGreeting: "Welcome, Driver"
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea()

                VStack(spacing: 16) {
                    // Mode Picker Selector (App Launched, Dashboard, Home Menu)
                    Picker("CarPlay Mode", selection: $activeMode) {
                        ForEach(CarPlayScreenMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Simulated Automotive In-Dash Display Bezel (800 x 480 standard CarPlay aspect ratio)
                    ZStack {
                        // Outer Head Unit Bezel
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.08, green: 0.09, blue: 0.11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color(red: 0.22, green: 0.25, blue: 0.32), lineWidth: 4)
                            )
                            .shadow(color: Color.black.opacity(0.8), radius: 18, y: 8)

                        // Head-Unit Screen Frame (720 x 420 aspect ratio)
                        HStack(spacing: 0) {
                            // Left-hand CarPlay Dock / Sidebar (Present in all CarPlay modes)
                            carPlayLeftDock

                            // Main CarPlay Screen Canvas
                            ZStack {
                                switch activeMode {
                                case .appLaunched:
                                    carPlayAppLaunchedView
                                case .dashboard:
                                    carPlayDashboardView
                                case .appMenu:
                                    carPlayAppMenuView
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                        }
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(8)
                    }
                    .frame(height: 280)
                    .padding(.horizontal, 12)

                    // Guidance Description Card
                    carPlayModeExplanation

                    Spacer()
                }
            }
            .navigationTitle("CarPlay Emulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.dashYellow)
                }
            }
            .onAppear {
                if let mode = CarPlayScreenMode.allCases.first(where: { $0.rawValue == appState.initialCarPlayMode }) {
                    activeMode = mode
                }
            }
        }
    }

    // MARK: - Left sidebar / dock (approximates the system car UI)

    private var carPlayLeftDock: some View {
        VStack(spacing: 10) {
            // Status bar (Time, 4G, Battery)
            VStack(spacing: 2) {
                Text("2:50")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)

                HStack(spacing: 2) {
                    Image(systemName: "cellularbars")
                        .font(.system(size: 9))
                    Text("4G")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.85))
            }
            .padding(.top, 8)

            Spacer()

            // Dynamic Recent App Icons in CarPlay Sidebar
            VStack(spacing: 8) {
                // Maps / Waze icon
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.95))

                // Podcasts icon
                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.6, green: 0.3, blue: 0.8))

                // Phone icon
                Image(systemName: "phone.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.dashGreen)

                // DashCast active car icon
                Image(systemName: "car.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.dashYellow)
            }

            Spacer()

            // Home / 8-dot App Launcher Button
            Button {
                withAnimation {
                    activeMode = (activeMode == .appMenu) ? .appLaunched : .appMenu
                }
            } label: {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 52)
        .background(Color(red: 0.12, green: 0.13, blue: 0.16))
    }

    // MARK: - View 1: CarPlay App Launched (Matching How the Carplay app launched from Carplay looks.jpeg)

    private var carPlayAppLaunchedView: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.09)

            VStack(spacing: 0) {
                // Top CarPlay Navigation Bar (Library, Favorites, Cast, Browser, Search)
                HStack(spacing: 0) {
                    let tabs = ["Library", "Favorites", "Cast", "Browser"]
                    ForEach(tabs, id: \.self) { tab in
                        let isSelected = selectedCarPlayTab == tab
                        Button {
                            selectedCarPlayTab = tab
                        } label: {
                            Text(tab)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Color.black : Color.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.dashYellow : Color.clear)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.trailing, 12)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(red: 0.14, green: 0.16, blue: 0.20))

                Spacer()

                // Center Hero Content
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.14, green: 0.18, blue: 0.26))
                            .frame(width: 60, height: 46)

                        Image(systemName: "rectangle.on.rectangle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.dashYellow)
                    }

                    VStack(spacing: 4) {
                        Text("Your channels, on the big screen")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.white)

                        Text("Add a media source in Cast on your iPhone to start streaming.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(white: 0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - View 2: CarPlay Dashboard (Matching How it should show up in the CarPlay.jpeg)

    private var carPlayDashboardView: some View {
        HStack(spacing: 8) {
            // Left Half: Navigation Map with Speed Limit Badge
            ZStack(alignment: .topTrailing) {
                // Street Map Simulation
                Rectangle()
                    .fill(Color(red: 0.18, green: 0.22, blue: 0.28))
                    .overlay(
                        VStack {
                            Path { path in
                                path.move(to: CGPoint(x: 20, y: 0))
                                path.addLine(to: CGPoint(x: 60, y: 220))
                                path.move(to: CGPoint(x: 120, y: 0))
                                path.addLine(to: CGPoint(x: 100, y: 220))
                            }
                            .stroke(Color.white.opacity(0.15), lineWidth: 4)
                        }
                    )

                // Street Name Banner
                VStack {
                    Spacer()
                    Text("Calle 77")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Speed Limit Badge (30 km/h)
                VStack(spacing: 2) {
                    Text("30")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.red)
                    Text("km/h")
                        .font(.system(size: 7))
                        .foregroundStyle(Color.black)
                }
                .padding(4)
                .background(Circle().fill(Color.white).overlay(Circle().stroke(Color.red, lineWidth: 2)))
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Right Half: Stacked Widgets (Audio Player + DashCast Widget)
            VStack(spacing: 8) {
                // Audio Player Widget
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.3, green: 0.5, blue: 0.4))
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: "music.note").foregroundStyle(.white))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cruising Beats")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Automotive Sound")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "pause.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(Color(red: 0.15, green: 0.16, blue: 0.20))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // DashCast Live Vehicle Widget
                HStack(spacing: 8) {
                    Image(activeWidget.carImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeWidget.driverGreeting)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                        Text(activeWidget.carModelName)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.dashYellow)
                    }

                    Spacer()
                }
                .padding(8)
                .background(Color(red: 0.15, green: 0.16, blue: 0.20))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(width: 175)
        }
        .padding(8)
    }

    // MARK: - View 3: CarPlay Home Menu (Matching This is how it should look like the other app on my carplay apps menu.jpeg)

    private var carPlayAppMenuView: some View {
        ZStack {
            // Wallpaper
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.22, blue: 0.28), Color(red: 0.08, green: 0.09, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 24) {
                // App 1: Headway
                carPlayAppIcon(
                    name: "Headway",
                    iconName: "ladder",
                    bgColor: Color(red: 0.1, green: 0.5, blue: 0.95)
                )

                // App 2: WA Business
                carPlayAppIcon(
                    name: "WA Business",
                    iconName: "message.fill",
                    bgColor: Color(red: 0.15, green: 0.8, blue: 0.4)
                )

                // App 3: DashCast (Our signature Racing Yellow automotive AppIcon!)
                Button {
                    withAnimation {
                        activeMode = .appLaunched
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LinearGradient.dashAccentGradient)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.dashYellow.opacity(0.4), radius: 8, y: 3)

                            Image(systemName: "car.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.black)
                        }

                        Text("DashCast")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }
    }

    private func carPlayAppIcon(name: String, iconName: String, bgColor: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(bgColor)
                    .frame(width: 60, height: 60)

                Image(systemName: iconName)
                    .font(.system(size: 26))
                    .foregroundStyle(Color.white)
            }

            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white)
        }
    }

    // MARK: - Mode Explanation Card

    private var carPlayModeExplanation: some View {
        AutomotiveCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.dashYellow)
                    Text("CarPlay Display Simulation")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)
                    Spacer()
                }

                Text(explanationText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashTextSecondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private var explanationText: String {
        switch activeMode {
        case .appLaunched:
            return "Matches the real in-car screen when DashCast is opened on your vehicle's head unit. Shows top tabs (Library, Favorites, Cast, Browser) and 1080p video canvas."
        case .dashboard:
            return "Matches the CarPlay split-screen Dashboard (Navigation map + Now Playing + live DashCast vehicle widget)."
        case .appMenu:
            return "Matches your vehicle's CarPlay home screen grid showing the DashCast app launcher next to your other car apps."
        }
    }
}
