import SwiftUI
import UIKit
import LinkPresentation

/// SwiftUI UIViewControllerRepresentable wrapper for native iOS UIActivityViewController.
public struct ShareSheetView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]?
    public var onComplete: ((UIActivity.ActivityType?, Bool) -> Void)?

    public init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil,
        onComplete: ((UIActivity.ActivityType?, Bool) -> Void)? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.onComplete = onComplete
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            onComplete?(activityType, completed)
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // UIActivityViewController is presented modally and does not require continuous re-renders
    }
}

/// Rich metadata item source for Instagram Stories, TikTok, Messages, and AirDrop shares.
public final class DriveSummaryActivityItemSource: NSObject, UIActivityItemSource {
    public let title: String
    public let message: String
    public let image: UIImage

    public init(title: String, message: String, image: UIImage) {
        self.title = title
        self.message = message
        self.image = image
        super.init()
    }

    public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    public func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if activityType == .airDrop || activityType == .saveToCameraRoll || activityType?.rawValue.contains("instagram") == true {
            return image
        }
        return image
    }

    public func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        title
    }

    public func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}
