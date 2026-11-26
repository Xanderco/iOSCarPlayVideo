import SwiftUI

public struct WidgetsHomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var savedWidgets: [WidgetConfigModel] = []
    @State private var showingEditor: Bool = false
    @State private var editingWidget: WidgetConfigModel?
    @State private var showingCarPlayGuide: Bool = false
    @State private var showingDoodleEditor: Bool = false
    @State private var activeCatalogCategory: WidgetTemplateCategory?

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

                        // Home Screen / CarPlay "Photo / Doodle" widget
                        Button {
                            showingDoodleEditor = true
                        } label: {
                            Label("Photo / Doodle widget", systemImage: "scribble.variable")
                                .font(ThemeFonts.hudCaption(size: 14))
                                .foregroundStyle(Color.dashYellow)
                        }
                        .accessibilityIdentifier("doodleWidgetButton")

                        // My Saved Widgets Switcher & Manager
                        myWidgetsSection

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
                            openEditor(with: WidgetConfigModel())
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black)
                                .frame(width: 32, height: 32)
                                .background(Color.dashYellow)
                                .clipShape(Circle())
                        }
                        .accessibilityIdentifier("Widgets_ToolbarAddButton")
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { showingEditor || appState.showWidgetEditor },
                set: { isPresented in
                    showingEditor = isPresented
                    appState.showWidgetEditor = isPresented
                    if !isPresented {
                        editingWidget = nil
                    }
                }
            )) {
                let target = editingWidget ?? WidgetConfigModel()
                let isExisting = savedWidgets.contains(where: { $0.id == target.id })
                WidgetEditorView(config: target, isEditingExisting: isExisting) { saved in
                    savedWidgets = WidgetTemplateCatalog.upsert(saved, in: savedWidgets)
                    PersistenceController.shared.saveWidgets(savedWidgets)
                }
            }
            .sheet(item: $activeCatalogCategory) { category in
                WidgetCategorySheetView(
                    category: category,
                    onSelectPreset: { preset in
                        openEditor(with: preset.makeFreshConfig())
                    },
                    onSelectBrand: { brand in
                        openEditor(with: WidgetTemplateCatalog.presetConfig(for: brand, catalog: catalog))
                    }
                )
            }
            .sheet(isPresented: $showingDoodleEditor) {
                DoodleEditorView()
            }
            .alert("Add Widgets to CarPlay", isPresented: $showingCarPlayGuide) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("1. Connect your iPhone to your CarPlay vehicle.\n2. On your car's display, swipe to the Dashboard view.\n3. DashCast widgets will automatically reflect your customized vehicle model, countdowns, and live status.")
            }
            .onAppear {
                loadInitialWidgets()
            }
        }
    }

    private var defaultWidget: WidgetConfigModel {
        WidgetConfigModel(carBrand: "Porsche", carModelName: "911 GT3 RS", carImageName: "car_porsche_911", driverGreeting: "Welcome, Driver")
    }

    // MARK: - Actions & Persistence

    private func loadInitialWidgets() {
        if !PersistenceController.shared.hasStoredWidgets {
            savedWidgets = WidgetTemplateCatalog.defaultStarterWidgets
            PersistenceController.shared.saveWidgets(savedWidgets)
        } else {
            savedWidgets = PersistenceController.shared.loadWidgets()
        }
    }

    private func openEditor(with config: WidgetConfigModel) {
        editingWidget = config
        showingEditor = true
    }

    private func activateWidget(_ widget: WidgetConfigModel) {
        savedWidgets = WidgetTemplateCatalog.activate(widget.id, in: savedWidgets)
        PersistenceController.shared.saveWidgets(savedWidgets)
    }

    private func deleteWidget(_ widget: WidgetConfigModel) {
        savedWidgets = WidgetTemplateCatalog.delete(widget.id, from: savedWidgets)
        PersistenceController.shared.saveWidgets(savedWidgets)
    }

    // MARK: - My Widgets Switcher

    private var myWidgetsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Text("My Widgets")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.dcTextPrimary)

                    Text("\(savedWidgets.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dcOnAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.dcAccent)
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    openEditor(with: WidgetConfigModel())
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dcAccent)
                }
                .accessibilityIdentifier("Widgets_AddNewButton")
            }
            .padding(.horizontal)

            if savedWidgets.isEmpty {
                VStack(spacing: 10) {
                    Text("No saved widgets yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dcTextSecondary)

                    Button {
                        openEditor(with: WidgetConfigModel())
                    } label: {
                        Text("Create Widget")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.dcOnAccent)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color.dcAccent)
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("Widgets_EmptyCreateButton")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.dcSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.dcStroke, lineWidth: 1)
                )
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(savedWidgets.enumerated()), id: \.element.id) { index, widget in
                            savedWidgetCard(widget: widget, index: index, isActive: index == 0)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Widgets_MyWidgetsSection")
    }

    private func savedWidgetCard(widget: WidgetConfigModel, index: Int, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if isActive {
                    Text("Active")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.dcOnAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.dcAccent)
                        .clipShape(Capsule())
                } else {
                    Text(widget.carBrand)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.dcTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    openEditor(with: widget)
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dcTextPrimary)
                        .frame(width: 26, height: 26)
                        .background(Color.dcSurfaceRaised)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Edit"))
                .accessibilityIdentifier("Widgets_EditWidget_\(index)")

                Button {
                    deleteWidget(widget)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dcDanger)
                        .frame(width: 26, height: 26)
                        .background(Color.dcSurfaceRaised)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Delete"))
                .accessibilityIdentifier("Widgets_DeleteWidget_\(index)")
            }

            Button {
                activateWidget(widget)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Image(widget.carImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)

                    Text(widget.carModelName)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.dcTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(widget.driverGreeting)
                            .font(.caption2)
                            .foregroundStyle(Color.dcTextSecondary)
                            .lineLimit(1)

                        if let plate = widget.plateText, !plate.isEmpty {
                            Spacer(minLength: 4)
                            Text(plate)
                                .font(.caption2.weight(.bold).monospaced())
                                .foregroundStyle(Color.dcTextPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.dcSurfaceRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Widgets_SavedCard_\(index)")
        }
        .padding(12)
        .frame(width: 172)
        .background(Color.dcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isActive ? Color.dcAccent : Color.dcStroke, lineWidth: isActive ? 2 : 1)
        )
        .contextMenu {
            Button {
                activateWidget(widget)
            } label: {
                Label("Set as Active", systemImage: "checkmark.circle")
            }

            Button {
                openEditor(with: widget)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                deleteWidget(widget)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Plate Widgets Section

    private var plateWidgetsSection: some View {
        let presets = WidgetTemplateCatalog.presets(for: .plate)
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Plate", category: .plate)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if let first = presets.first {
                        Button {
                            openEditor(with: first.makeFreshConfig())
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.dashSurface)
                                    .frame(width: 140, height: 140)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dashBorder, lineWidth: 1))

                                VStack(spacing: 10) {
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
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(first.id)")
                    }

                    if presets.count > 1 {
                        let second = presets[1]
                        Button {
                            openEditor(with: second.makeFreshConfig())
                        } label: {
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
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(second.id)")
                    }

                    if presets.count > 2 {
                        let third = presets[2]
                        Button {
                            openEditor(with: third.makeFreshConfig())
                        } label: {
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
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(third.id)")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Couple Days / Anniversary

    private var coupleDaysSection: some View {
        let presets = WidgetTemplateCatalog.presets(for: .coupleDays)
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Couple Days", category: .coupleDays)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if let first = presets.first {
                        Button {
                            openEditor(with: first.makeFreshConfig())
                        } label: {
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
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(first.id)")
                    }

                    if presets.count > 1 {
                        let second = presets[1]
                        Button {
                            openEditor(with: second.makeFreshConfig())
                        } label: {
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
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(second.id)")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Date & Time

    private var dateTimeSection: some View {
        let presets = WidgetTemplateCatalog.presets(for: .dateTime)
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Date & Time", category: .dateTime)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if let first = presets.first {
                        Button {
                            openEditor(with: first.makeFreshConfig())
                        } label: {
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
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(first.id)")
                    }

                    if presets.count > 1 {
                        let second = presets[1]
                        Button {
                            openEditor(with: second.makeFreshConfig())
                        } label: {
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
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(second.id)")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Countdown

    private var countdownSection: some View {
        let presets = WidgetTemplateCatalog.presets(for: .countdown)
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Countdown", category: .countdown)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if let first = presets.first {
                        Button {
                            openEditor(with: first.makeFreshConfig())
                        } label: {
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
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(first.id)")
                    }

                    if presets.count > 1 {
                        let second = presets[1]
                        Button {
                            openEditor(with: second.makeFreshConfig())
                        } label: {
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
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(second.id)")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Vinyl Record

    private var vinylRecordSection: some View {
        let presets = WidgetTemplateCatalog.presets(for: .vinylRecord)
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Vinyl Record", category: .vinylRecord)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if let first = presets.first {
                        Button {
                            openEditor(with: first.makeFreshConfig())
                        } label: {
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
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(first.id)")
                    }

                    if presets.count > 1 {
                        let second = presets[1]
                        Button {
                            openEditor(with: second.makeFreshConfig())
                        } label: {
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
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(second.id)")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Daily Quote

    private var dailyQuoteSection: some View {
        let presets = WidgetTemplateCatalog.presets(for: .dailyQuote)
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Daily Quote", category: .dailyQuote)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if let first = presets.first {
                        Button {
                            openEditor(with: first.makeFreshConfig())
                        } label: {
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
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(first.id)")
                    }

                    if presets.count > 1 {
                        let second = presets[1]
                        Button {
                            openEditor(with: second.makeFreshConfig())
                        } label: {
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
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_TemplateCard_\(second.id)")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 100+ Brands Section

    private var brandsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "100+ Car Brands", category: .carBrands)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(catalog.brands) { brand in
                        Button {
                            openEditor(with: WidgetTemplateCatalog.presetConfig(for: brand, catalog: catalog))
                        } label: {
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
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Widgets_BrandTile_\(brand.id)")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func sectionHeader(title: LocalizedStringKey, category: WidgetTemplateCategory) -> some View {
        HStack {
            Text(title)
                .font(ThemeFonts.hudTitle(size: 18))
                .foregroundStyle(Color.dashTextPrimary)

            Spacer()

            Button("See all") {
                activeCatalogCategory = category
            }
            .font(ThemeFonts.hudCaption(size: 13))
            .foregroundStyle(Color.dashYellow)
            .accessibilityIdentifier("Widgets_SeeAll_\(category.rawValue)")
        }
        .padding(.horizontal)
    }
}
