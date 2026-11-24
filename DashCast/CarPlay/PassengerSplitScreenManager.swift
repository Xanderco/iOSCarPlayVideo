import SwiftUI
import Combine

/// Manages layout and mode selection for CarPlay external displays and split-screen video.
@MainActor
public final class PassengerSplitScreenManager: ObservableObject {
    public static let shared = PassengerSplitScreenManager()

    public enum SplitMode: String, CaseIterable, Identifiable {
        case splitSidebar = "Split Sidebar"
        case fullVideo = "Full Video"
        case fullTelemetry = "Telemetry Only"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .splitSidebar: return "rectangle.split.2x1.fill"
            case .fullVideo: return "rectangle.fill"
            case .fullTelemetry: return "gauge.with.needle.fill"
            }
        }
    }

    @Published public var currentMode: SplitMode = .splitSidebar
    @Published public var isSafetyBannerDismissed: Bool = false
    @Published public var isInteracting: Bool = false

    public init() {}

    public func cycleMode() {
        switch currentMode {
        case .splitSidebar:
            currentMode = .fullVideo
        case .fullVideo:
            currentMode = .fullTelemetry
        case .fullTelemetry:
            currentMode = .splitSidebar
        }
    }

    public func setMode(_ mode: SplitMode) {
        self.currentMode = mode
    }

    public func dismissSafetyBanner() {
        self.isSafetyBannerDismissed = true
    }

    public func resetSafetyBanner() {
        self.isSafetyBannerDismissed = false
    }
}
