import CarPlay
import UIKit

public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    public var interfaceController: CPInterfaceController?

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupCarPlayRootTemplate(interfaceController: interfaceController)
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: CarPlay window (mirror iPhone to the car screen)
    // iOS only calls these when the app holds a CarPlay entitlement that grants a
    // drawable window (see ADR-002 §7). Without it they are never called and the
    // template UI above is the graceful fallback.

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        setupCarPlayRootTemplate(interfaceController: interfaceController)
        MainActor.assumeIsolated { CarPlayMirrorController.shared.attach(to: window) }
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        self.interfaceController = nil
        MainActor.assumeIsolated { CarPlayMirrorController.shared.detach() }
    }

    private func setupCarPlayRootTemplate(interfaceController: CPInterfaceController) {
        // Templates used here are all allowed for the CarPlay Audio category
        // (tab bar, list, Now Playing). CPInformationTemplate is NOT allowed for
        // audio apps and would throw, so the mirroring instructions are a list.
        let tabBar = CPTabBarTemplate(templates: [
            Self.libraryTemplate(),
            Self.favoritesTemplate(),
            Self.nowPlayingTabTemplate(interfaceController: interfaceController),
            Self.mirrorInstructionsTemplate()
        ])
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)
    }

    // MARK: Tabs

    static func libraryTemplate() -> CPListTemplate {
        let items: [CPListItem] = IPTVParser.samplePlaylist.map { channel in
            let item = CPListItem(text: channel.name, detailText: channel.groupTitle)
            item.handler = { _, completion in
                Task { @MainActor in
                    VideoPlayerService.shared.load(channel: channel)
                    completion()
                }
            }
            return item
        }
        let template = CPListTemplate(title: "Library", sections: [CPListSection(items: items)])
        template.tabTitle = "Library"
        template.tabImage = UIImage(systemName: "tv.fill")
        return template
    }

    static func favoritesTemplate() -> CPListTemplate {
        let template = CPListTemplate(title: "Favorites", sections: [
            CPListSection(items: [
                CPListItem(text: "No Favorites Yet", detailText: "Add favorites from your iPhone")
            ])
        ])
        template.tabTitle = "Favorites"
        template.tabImage = UIImage(systemName: "heart.fill")
        return template
    }

    static func nowPlayingTabTemplate(interfaceController: CPInterfaceController) -> CPListTemplate {
        let open = CPListItem(
            text: "Now Playing",
            detailText: "Audio plays through the car while driving",
            image: UIImage(systemName: "play.circle.fill")
        )
        open.handler = { _, completion in
            interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            completion()
        }
        let template = CPListTemplate(title: "Now Playing", sections: [CPListSection(items: [open])])
        template.tabTitle = "Now Playing"
        template.tabImage = UIImage(systemName: "waveform")
        return template
    }

    /// Car-screen instructions for mirroring the iPhone (shown as the "Cast" tab).
    static func mirrorInstructionsTemplate() -> CPListTemplate {
        let steps = mirrorInstructionSteps.enumerated().map { index, step -> CPListItem in
            let item = CPListItem(
                text: step.title,
                detailText: step.detail,
                image: UIImage(systemName: "\(index + 1).circle.fill")
            )
            item.isEnabled = false
            return item
        }
        let template = CPListTemplate(
            title: "Mirror iPhone",
            sections: [CPListSection(items: steps, header: "Show your iPhone on this screen", sectionIndexTitle: nil)]
        )
        template.tabTitle = "Cast"
        template.tabImage = UIImage(systemName: "rectangle.on.rectangle")
        return template
    }

    /// Original copy; also used by the unit tests.
    static let mirrorInstructionSteps: [(title: String, detail: String)] = [
        ("Open DashCast on your iPhone", "Go to Cast → Car Display."),
        ("Turn on “Mirror to CarPlay screen”", "Then tap the broadcast button and choose Start Broadcast."),
        ("Parked only", "Mirroring stops automatically as soon as the vehicle moves.")
    ]
}
