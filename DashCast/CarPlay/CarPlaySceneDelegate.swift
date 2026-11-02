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

    private func setupCarPlayRootTemplate(interfaceController: CPInterfaceController) {
        // Tab 1: Library (Channels & Videos)
        let libraryItems: [CPListItem] = IPTVParser.samplePlaylist.map { channel in
            let item = CPListItem(text: channel.name, detailText: channel.groupTitle)
            item.handler = { [weak self] _, completion in
                Task { @MainActor in
                    VideoPlayerService.shared.load(channel: channel)
                    completion()
                }
            }
            return item
        }
        let libraryList = CPListTemplate(title: "Library", sections: [CPListSection(items: libraryItems)])
        libraryList.tabTitle = "Library"
        libraryList.tabImage = UIImage(systemName: "tv.fill")

        // Tab 2: Favorites
        let favoritesList = CPListTemplate(title: "Favorites", sections: [
            CPListSection(items: [
                CPListItem(text: "No Favorites Yet", detailText: "Add favorites from your iPhone")
            ])
        ])
        favoritesList.tabTitle = "Favorites"
        favoritesList.tabImage = UIImage(systemName: "heart.fill")

        // Tab 3: Cast (Status & Guidance - Matches "Your channels, on the big screen")
        let castItems: [CPListItem] = [
            CPListItem(text: "Your channels, on the big screen", detailText: "Cast IPTV, YouTube or local videos from iPhone"),
            CPListItem(text: "Parked Video Mode", detailText: "Videos stream in full 1080p when parked")
        ]
        let castList = CPListTemplate(title: "Cast", sections: [CPListSection(items: castItems)])
        castList.tabTitle = "Cast"
        castList.tabImage = UIImage(systemName: "rectangle.on.rectangle.fill")

        // Tab 4: Browser
        let browserItems: [CPListItem] = [
            CPListItem(text: "YouTube", detailText: "Stream online videos"),
            CPListItem(text: "Twitch", detailText: "Live streams"),
            CPListItem(text: "Vimeo", detailText: "High definition clips")
        ]
        let browserList = CPListTemplate(title: "Browser", sections: [CPListSection(items: browserItems)])
        browserList.tabTitle = "Browser"
        browserList.tabImage = UIImage(systemName: "globe")

        // Tab Bar Template hosting the 4 CarPlay tabs
        let tabBar = CPTabBarTemplate(templates: [castList, libraryList, favoritesList, browserList])
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)
    }
}
