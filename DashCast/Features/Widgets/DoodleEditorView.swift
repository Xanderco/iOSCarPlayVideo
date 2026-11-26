import PhotosUI
import SwiftUI

/// Pure validation, geometry, and localization helpers for `DoodleEditorView`.
public enum DoodleEditorLogic {
    public enum Mode: String, CaseIterable, Identifiable, Sendable {
        case doodle = "Doodle"
        case photo = "Photo"

        public var id: String { rawValue }

        @MainActor
        public var titleKey: LocalizedStringKey {
            LocalizedStringKey(rawValue)
        }
    }

    nonisolated public static let maxCaptionLength: Int = 24

    nonisolated public static let allLocalizationKeys: [String] = [
        "Photo / Doodle widget",
        "Doodle",
        "Photo",
        "Type",
        "Caption (optional)",
        "Drawing canvas",
        "Undo",
        "Clear",
        "Choose photo",
        "Cancel",
        "Save"
    ]

    @MainActor
    public static var navigationTitleKey: LocalizedStringKey {
        LocalizedStringKey("Photo / Doodle widget")
    }

    @MainActor
    public static var typePickerTitleKey: LocalizedStringKey {
        LocalizedStringKey("Type")
    }

    @MainActor
    public static var captionPlaceholderKey: LocalizedStringKey {
        LocalizedStringKey("Caption (optional)")
    }

    @MainActor
    public static var drawingCanvasAccessibilityKey: LocalizedStringKey {
        LocalizedStringKey("Drawing canvas")
    }

    @MainActor
    public static var undoAccessibilityKey: LocalizedStringKey {
        LocalizedStringKey("Undo")
    }

    @MainActor
    public static var clearAccessibilityKey: LocalizedStringKey {
        LocalizedStringKey("Clear")
    }

    @MainActor
    public static var choosePhotoTitleKey: LocalizedStringKey {
        LocalizedStringKey("Choose photo")
    }

    @MainActor
    public static var cancelTitleKey: LocalizedStringKey {
        LocalizedStringKey("Cancel")
    }

    @MainActor
    public static var saveTitleKey: LocalizedStringKey {
        LocalizedStringKey("Save")
    }

    nonisolated public static func normalizedCaption(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxCaptionLength))
    }

    nonisolated public static func clampedPoint(_ point: CGPoint, canvasSide: CGFloat) -> CGPoint {
        guard canvasSide.isFinite, canvasSide > 0 else {
            return .zero
        }
        let x = point.x.isFinite ? min(max(point.x, 0), canvasSide) : 0
        let y = point.y.isFinite ? min(max(point.y, 0), canvasSide) : 0
        return CGPoint(x: x, y: y)
    }

    nonisolated public static func canSave(mode: Mode, strokeCount: Int, hasPhoto: Bool) -> Bool {
        switch mode {
        case .doodle:
            return strokeCount > 0
        case .photo:
            return hasPhoto
        }
    }
}

/// Lets the user pick a photo or draw a quick doodle for the "Photo / Doodle" Home Screen widget.
struct DoodleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    typealias Mode = DoodleEditorLogic.Mode

    struct Stroke: Identifiable {
        let id = UUID()
        var points: [CGPoint]
        var color: Color
        var width: CGFloat
    }

    @State private var mode: Mode = .doodle
    @State private var strokes: [Stroke] = []
    @State private var current: Stroke?
    @State private var inkColor: Color = Color(red: 0.08, green: 0.13, blue: 0.22)
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var caption: String = ""

    private let palette: [Color] = [
        Color(red: 0.08, green: 0.13, blue: 0.22), .red, .orange, Color(red: 0.12, green: 0.6, blue: 0.52), .blue, .purple
    ]
    private let canvasSide: CGFloat = 300

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker(DoodleEditorLogic.typePickerTitleKey, selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.titleKey).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .doodle { doodlePad } else { photoPad }

                TextField(DoodleEditorLogic.captionPlaceholderKey, text: $caption)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("doodleCaption")
                Spacer()
            }
            .padding()
            .navigationTitle(DoodleEditorLogic.navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(DoodleEditorLogic.cancelTitleKey) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(DoodleEditorLogic.saveTitleKey) { save(); dismiss() }.disabled(!canSave)
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { photoData = try? await item?.loadTransferable(type: Data.self) }
            }
        }
    }

    private var canSave: Bool {
        DoodleEditorLogic.canSave(mode: mode, strokeCount: strokes.count, hasPhoto: photoData != nil)
    }

    private var drawing: some View {
        Canvas { context, _ in
            for stroke in strokes + (current.map { [$0] } ?? []) {
                var path = Path()
                path.addLines(stroke.points)
                context.stroke(path, with: .color(stroke.color),
                               style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: canvasSide, height: canvasSide)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.97, green: 0.96, blue: 0.92)))
    }

    private var doodlePad: some View {
        VStack(spacing: 12) {
            drawing
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let p = DoodleEditorLogic.clampedPoint(value.location, canvasSide: canvasSide)
                    if current == nil { current = Stroke(points: [p], color: inkColor, width: 9) }
                    current?.points.append(p)
                }.onEnded { _ in
                    if let current { strokes.append(current) }
                    current = nil
                })
                .accessibilityLabel(DoodleEditorLogic.drawingCanvasAccessibilityKey)
            HStack(spacing: 12) {
                ForEach(palette.indices, id: \.self) { i in
                    Circle().fill(palette[i])
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.white, lineWidth: inkColor == palette[i] ? 3 : 0))
                        .onTapGesture { inkColor = palette[i] }
                }
                Spacer()
                Button { if !strokes.isEmpty { strokes.removeLast() } } label: { Image(systemName: "arrow.uturn.backward") }
                    .accessibilityLabel(DoodleEditorLogic.undoAccessibilityKey)
                Button { strokes.removeAll() } label: { Image(systemName: "trash") }
                    .accessibilityLabel(DoodleEditorLogic.clearAccessibilityKey)
            }
        }
    }

    private var photoPad: some View {
        VStack(spacing: 12) {
            Group {
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                }
            }
            .frame(width: canvasSide, height: canvasSide)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(DoodleEditorLogic.choosePhotoTitleKey, systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @MainActor
    private func save() {
        let text = DoodleEditorLogic.normalizedCaption(caption)
        switch mode {
        case .photo:
            guard let data = photoData, let thumb = WidgetSharedPublisher.thumbnail(from: data, maxSide: 400) else { return }
            WidgetSharedPublisher.publishDoodle(SharedDoodle(kind: .photo, imageData: thumb, caption: text))
        case .doodle:
            let renderer = ImageRenderer(content: Canvas { context, _ in
                for stroke in strokes {
                    var path = Path()
                    path.addLines(stroke.points)
                    context.stroke(path, with: .color(stroke.color),
                                   style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
                }
            }.frame(width: canvasSide, height: canvasSide))
            renderer.scale = 1.5
            guard let png = renderer.uiImage?.pngData() else { return }
            WidgetSharedPublisher.publishDoodle(SharedDoodle(kind: .doodle, imageData: png, caption: text))
        }
    }
}
