import SwiftUI
import AVKit

public struct AirPlayRoutePickerRepresentable: UIViewRepresentable {
    public var tintColor: Color

    public init(tintColor: Color = .dcAccent) {
        self.tintColor = tintColor
    }

    public func makeUIView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        routePicker.tintColor = UIColor(tintColor)
        routePicker.activeTintColor = UIColor(Color.dcSuccess)
        routePicker.prioritizesVideoDevices = true
        routePicker.backgroundColor = .clear
        return routePicker
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = UIColor(tintColor)
    }
}
