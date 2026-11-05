import SwiftUI
import ReplayKit

/// System broadcast picker pre-targeted at DashCast's own Broadcast Upload
/// Extension (DashCastBroadcast), so one tap starts car-browser mirroring.
public struct ScreenBroadcastPickerView: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = CarCastShared.broadcastExtensionBundleID(hostBundleID: Bundle.main.bundleIdentifier)
        picker.showsMicrophoneButton = false
        if let button = picker.subviews.first(where: { $0 is UIButton }) as? UIButton {
            button.tintColor = UIColor(Color.dashYellow)
        }
        return picker
    }

    public func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
