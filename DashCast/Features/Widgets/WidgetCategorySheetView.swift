import SwiftUI

struct WidgetCategorySheetView: View {
    @Environment(\.dismiss) private var dismiss
    let category: WidgetTemplateCategory
    let onSelectPreset: (WidgetTemplatePreset) -> Void
    let onSelectBrand: (VehicleBrand) -> Void

    @State private var searchText: String = ""
    private let catalog = VehicleCatalogService.shared

    private var filteredBrands: [VehicleBrand] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return catalog.brands }
        return catalog.brands.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.country.localizedCaseInsensitiveContains(query)
        }
    }

    private var presets: [WidgetTemplatePreset] {
        WidgetTemplateCatalog.presets(for: category)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dcBackground.ignoresSafeArea()

                ScrollView {
                    if category == .carBrands {
                        brandsGrid
                    } else {
                        presetsGrid
                    }
                }
            }
            .navigationTitle(category.navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.dcAccent)
                    .accessibilityIdentifier("WidgetCategorySheet_Done")
                }
            }
            .if(category == .carBrands) { view in
                view.searchable(text: $searchText, prompt: Text("Search car brands"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("WidgetCategorySheet_\(category.rawValue)")
    }

    private var presetsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(presets) { preset in
                Button {
                    onSelectPreset(preset)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(preset.previewBadge)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.dcOnAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.dcAccent)
                                .clipShape(Capsule())

                            Spacer()

                            Image(systemName: "slider.horizontal.3")
                                .font(.caption)
                                .foregroundStyle(Color.dcTextSecondary)
                        }

                        Image(preset.templateConfig.carImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.dcTextPrimary)
                                .lineLimit(1)

                            Text(preset.subtitle)
                                .font(.caption)
                                .foregroundStyle(Color.dcTextSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dcSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.dcStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("WidgetPreset_\(preset.id)")
            }
        }
        .padding()
    }

    private var brandsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(filteredBrands) { brand in
                Button {
                    onSelectBrand(brand)
                    dismiss()
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.dcSurfaceRaised)
                                .frame(height: 66)

                            if let vehicle = catalog.vehicles(for: brand.id).first {
                                Image(vehicle.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 46)
                                    .padding(.horizontal, 6)
                            } else {
                                Image(systemName: "steeringwheel")
                                    .font(.title2)
                                    .foregroundStyle(Color.dcAccent)
                            }
                        }

                        Text(brand.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.dcTextPrimary)
                            .lineLimit(1)

                        Text(brand.country)
                            .font(.caption2)
                            .foregroundStyle(Color.dcTextTertiary)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.dcSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.dcStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("WidgetBrand_\(brand.id)")
            }
        }
        .padding()
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
