import SwiftUI
import PhotosUI
import UIKit

/// Settings › Car Extras › Car Screen: the short text the car display shows while nothing is
/// playing. Stored as the first `WidgetConfigModel`, which the external display reads.
public struct CarScreenView: View {
    private enum Field: Hashable { case label, greeting, subtitle, plate }


    @State private var config: WidgetConfigModel = CarScreenView.loadConfig()
    @FocusState private var focusedField: Field?
    @State private var photoItem: PhotosPickerItem?

    public init() {}

    public var body: some View {
        List {
            Section {
                CarScreenPreview(label: config.carBrand, greeting: config.driverGreeting, subtitle: config.carModelName)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } footer: {
                Text("Shown on the car display between videos. Video always takes over the whole screen.")
            }

            Section {
                limitedField("Label", text: $config.carBrand, limit: CarScreenDefaults.labelLimit, field: .label, prompt: "Family car")
                limitedField("Greeting", text: $config.driverGreeting, limit: CarScreenDefaults.textLimit, field: .greeting, prompt: "Welcome aboard")
                limitedField("Second line", text: $config.carModelName, limit: CarScreenDefaults.textLimit, field: .subtitle, prompt: "Pick something to watch")
            } header: {
                Text("Text")
            }

            Section {
                limitedField("Plate", text: Binding(
                    get: { config.plateText ?? "" },
                    set: { config.plateText = $0.isEmpty ? nil : $0 }
                ), limit: 12, field: .plate, prompt: "Optional")
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(config.customPhotoData == nil ? "Add a Photo of Your Car" : "Change Photo", systemImage: "photo")
                }
                if config.customPhotoData != nil {
                    Button("Remove Photo", role: .destructive) {
                        config.customPhotoData = nil
                        save()
                    }
                }
            } header: {
                Text("Home Screen widget")
            } footer: {
                Text("Your own photo and plate appear on DashCast's Home Screen widget.")
            }

            Section {
                Button("Reset to Default", role: .destructive) {
                    let fresh = CarScreenDefaults.neutralConfig()
                    config.carBrand = fresh.carBrand
                    config.driverGreeting = fresh.driverGreeting
                    config.carModelName = fresh.carModelName
                    config.plateText = nil
                }
            }
        }
        .tint(Color.dcAccent)
        .scrollContentBackground(.hidden)
        .background(Color.dcBackgroundElevated.ignoresSafeArea())
        .navigationTitle("Car Screen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onChange(of: config.carBrand) { _, _ in save() }
        .onChange(of: config.driverGreeting) { _, _ in save() }
        .onChange(of: config.carModelName) { _, _ in save() }
        .onChange(of: config.plateText) { _, _ in save() }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let resized = CarScreenDefaults.downscaledJPEG(from: data) {
                    config.customPhotoData = resized
                    save()
                }
                photoItem = nil
            }
        }
    }

    private func limitedField(_ title: String, text: Binding<String>, limit: Int, field: Field, prompt: String) -> some View {
        LabeledContent {
            TextField(title, text: Binding(
                get: { text.wrappedValue },
                set: { text.wrappedValue = String($0.prefix(limit)) }
            ), prompt: Text(prompt))
            .multilineTextAlignment(.trailing)
            .focused($focusedField, equals: field)
            .submitLabel(.done)
        } label: {
            Text(title)
        }
    }

    // MARK: Persistence

    static func loadConfig() -> WidgetConfigModel {
        PersistenceController.shared.loadWidgets().first ?? CarScreenDefaults.neutralConfig()
    }

    private func save() {
        var widgets = PersistenceController.shared.loadWidgets()
        var updated = config
        // Stock vehicle renders are no longer bundled; the car display falls back to a symbol.
        updated.carImageName = ""
        if widgets.isEmpty {
            widgets = [updated]
        } else {
            widgets[0] = updated
        }
        PersistenceController.shared.saveWidgets(widgets)
        UsageMetricsManager.shared.recordWidgetCustomization()
    }
}

/// Non-UI helpers for Car Screen (kept off the View so tests and AppState can call them from any context).
public enum CarScreenDefaults {
    public static let labelLimit = 24
    public static let textLimit = 36

    /// DashCast's own default text for the car display (the model's legacy defaults name a real car).
    public static func neutralConfig() -> WidgetConfigModel {
        WidgetConfigModel(
            carBrand: "My Car",
            carModelName: "Pick something to watch",
            carImageName: "",
            driverGreeting: "Welcome aboard",
            plateText: nil
        )
    }

    /// Saves the neutral config on first launch so the car display never falls back to stock car text.
    public static func seedIfNeeded(persistence: PersistenceController = .shared) {
        guard persistence.loadWidgets().isEmpty else { return }
        persistence.saveWidgets([neutralConfig()])
    }

    public static func downscaledJPEG(from data: Data, maxSide: CGFloat = 1024) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

/// A 16:9 preview of the idle car display, drawn with DashCast tokens.
public struct CarScreenPreview: View {
    public let label: String
    public let greeting: String
    public let subtitle: String

    public init(label: String, greeting: String, subtitle: String) {
        self.label = label
        self.greeting = greeting
        self.subtitle = subtitle
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .fill(Color.dcVideoChrome)
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: DSStroke.regular)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(label.isEmpty ? " " : label.uppercased())
                    .font(DSTypography.badge)
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.6))
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: DSSpacing.md) {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Text(greeting.isEmpty ? " " : greeting)
                            .font(DSTypography.title2)
                            .foregroundStyle(Color.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text(subtitle.isEmpty ? " " : subtitle)
                            .font(DSTypography.subheadline)
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.dcAccent)
                        .accessibilityHidden(true)
                }
            }
            .padding(DSSpacing.lg)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Car screen preview: \(label). \(greeting). \(subtitle)"))
    }
}

#Preview("Car Screen") {
    NavigationStack { CarScreenView() }
        .preferredColorScheme(.dark)
}
