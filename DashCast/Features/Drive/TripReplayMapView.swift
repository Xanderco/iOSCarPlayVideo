import SwiftUI
import MapKit

/// Route replay for a saved trip: the full route in a muted colour, the travelled part in the
/// accent colour, and a car marker moved by Play or by scrubbing.
public struct TripReplayMapView: View {
    public let coordinates: [CLLocationCoordinate2D]

    @State private var progress: Double = 1
    @State private var isPlaying = false
    @State private var playTask: Task<Void, Never>?

    public init(coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
    }

    /// Index of the marker for a 0...1 progress. Exposed for tests.
    nonisolated public static func index(for progress: Double, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let clamped = min(max(progress, 0), 1)
        return Int((clamped * Double(count - 1)).rounded())
    }

    private var currentIndex: Int { Self.index(for: progress, count: coordinates.count) }

    public var body: some View {
        VStack(spacing: DSSpacing.sm) {
            if coordinates.isEmpty {
                EmptyStateView(
                    systemImage: "map",
                    title: "No Route Recorded",
                    message: "The trip was too short or location was unavailable."
                )
                .frame(height: 260)
            } else {
                Map(initialPosition: .automatic) {
                    if coordinates.count > 1 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(Color.dcTextSecondary.opacity(0.5), lineWidth: 5)
                        if currentIndex > 0 {
                            MapPolyline(coordinates: Array(coordinates[0...currentIndex]))
                                .stroke(Color.dcAccent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        }
                    }
                    Annotation("", coordinate: coordinates[currentIndex], anchor: .center) {
                        Image(systemName: "car.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, Color.dcAccent)
                            .accessibilityHidden(true)
                    }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                .accessibilityLabel(Text("Route map"))

                if coordinates.count > 1 {
                    HStack(spacing: DSSpacing.sm) {
                        Button {
                            isPlaying ? stop() : play()
                        } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.dcAccent)
                                .frame(width: DSLayout.minTapTarget, height: DSLayout.minTapTarget)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text(isPlaying ? "Pause replay" : "Replay route"))

                        Slider(value: $progress, in: 0...1) { Text("Replay position") }
                            .tint(Color.dcAccent)
                            .accessibilityLabel(Text("Replay position slider"))
                    }
                    .padding(.horizontal, DSSpacing.sm)
                }
            }
        }
        .onDisappear(perform: stop)
    }

    private func play() {
        if progress >= 1 { progress = 0 }
        isPlaying = true
        playTask?.cancel()
        playTask = Task { @MainActor in
            // Whole route in ~10 s regardless of length.
            let step = 1.0 / 200.0
            while !Task.isCancelled && progress < 1 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                progress = min(progress + step, 1)
            }
            isPlaying = false
        }
    }

    private func stop() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
    }
}
