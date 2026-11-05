import PhotosUI
import SwiftUI

/// Lets the user pick a photo or draw a quick doodle for the "Photo / Doodle" Home Screen widget.
struct DoodleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    struct Stroke: Identifiable {
        let id = UUID()
        var points: [CGPoint]
        var color: Color
        var width: CGFloat
    }

    enum Mode: String, CaseIterable, Identifiable {
        case doodle = "Doodle", photo = "Photo"
        var id: String { rawValue }
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
                Picker("Type", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if mode == .doodle { doodlePad } else { photoPad }

                TextField("Caption (optional)", text: $caption)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("doodleCaption")
                Spacer()
            }
            .padding()
            .navigationTitle("Photo / Doodle widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }.disabled(!canSave)
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { photoData = try? await item?.loadTransferable(type: Data.self) }
            }
        }
    }

    private var canSave: Bool { mode == .doodle ? !strokes.isEmpty : photoData != nil }

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
                    let p = CGPoint(x: min(max(value.location.x, 0), canvasSide), y: min(max(value.location.y, 0), canvasSide))
                    if current == nil { current = Stroke(points: [p], color: inkColor, width: 9) }
                    current?.points.append(p)
                }.onEnded { _ in
                    if let current { strokes.append(current) }
                    current = nil
                })
                .accessibilityLabel("Drawing canvas")
            HStack(spacing: 12) {
                ForEach(palette.indices, id: \.self) { i in
                    Circle().fill(palette[i])
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.white, lineWidth: inkColor == palette[i] ? 3 : 0))
                        .onTapGesture { inkColor = palette[i] }
                }
                Spacer()
                Button { if !strokes.isEmpty { strokes.removeLast() } } label: { Image(systemName: "arrow.uturn.backward") }
                    .accessibilityLabel("Undo")
                Button { strokes.removeAll() } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Clear")
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
                Label("Choose photo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @MainActor
    private func save() {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let text: String? = trimmed.isEmpty ? nil : String(trimmed.prefix(24))
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
