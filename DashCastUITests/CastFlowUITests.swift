import XCTest

/// Cast tab flows: playlists (stubbed network), favorites, local playback + mini player,
/// car mode, browser, help and mirroring sheets.
final class CastFlowUITests: DashCastUITestCase {
    private let bundledSample = "Night Highway Drive (Bundled 1080p)"

    private func openMediaSources() {
        tap(app.buttons["Cast_MediaSourceRow"])
        waitFor(navBar("Media Sources"), "Media Sources sheet")
    }

    private func closeMediaSources() {
        tap(navBar("Media Sources").buttons["Done"])
        waitForDisappearance(navBar("Media Sources"))
    }

    func testMediaSourcesListsBundledSampleChannels() {
        launch()
        openMediaSources()
        waitFor(app.buttons.matching(identifier: "MediaSources_Channel").firstMatch, "channel rows")
        waitFor(buttonWithLabel(bundledSample), "bundled sample channel")
        snapshot("03-media-sources")
        closeMediaSources()
    }

    func testAddPlaylistFromURLUsesStubbedNetwork() {
        launch()
        openMediaSources()

        tap(element("MediaSources_AddMenu"))
        tap(buttonWithLabel("From URL"))
        waitFor(navBar("Add Stream"), "Add Stream sheet")

        let field = app.textFields["AddStream_URLField"]
        tap(field)
        field.typeText("https://stub.dashcast.test/playlist.m3u")
        snapshot("04-add-playlist-url")
        tap(app.buttons["AddStream_ImportButton"])

        waitForDisappearance(navBar("Add Stream"), "Add sheet should close after import")
        let success = app.staticTexts["MediaSources_ImportSuccess"]
        waitFor(success, "import success message")
        waitForLabel(success, containing: "Imported 3 channels")
        waitFor(buttonWithLabel("Stub Channel 1"), "imported channel 1")
        waitFor(buttonWithLabel("Stub Channel 3"), "imported channel 3")
        snapshot("05-playlist-imported")
    }

    func testAddPlaylistShowsErrorForMissingPlaylist() {
        launch()
        openMediaSources()
        tap(element("MediaSources_AddMenu"))
        tap(buttonWithLabel("From URL"))
        let field = app.textFields["AddStream_URLField"]
        tap(field)
        field.typeText("https://stub.dashcast.test/missing.m3u")
        tap(app.buttons["AddStream_ImportButton"])

        let alert = app.alerts["Couldn't import playlist"]
        waitFor(alert, "error alert for HTTP 404")
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "404")).firstMatch.exists)
        snapshot("06-import-error")
        alert.buttons["OK"].tap()
    }

    func testFavoritesEmptyStateThenToggleFromMediaSources() {
        launch()
        tap(app.buttons["Cast_FavoritesButton"])
        waitFor(navBar("Favorites"))
        waitFor(element("Favorites_Empty"), "empty favorites state")
        tap(navBar("Favorites").buttons["Close"])
        waitForDisappearance(navBar("Favorites"))

        openMediaSources()
        let heart = buttonWithLabel("Add \(bundledSample) to favorites")
        tap(heart)
        waitFor(buttonWithLabel("Remove \(bundledSample) from favorites"), "heart should toggle on")
        closeMediaSources()

        tap(app.buttons["Cast_FavoritesButton"])
        waitFor(navBar("Favorites"))
        waitFor(buttonWithLabel(bundledSample), "favorite should be listed")
        snapshot("07-favorites")
    }

    func testSeededFavoriteIsListed() {
        launch(extraArguments: ["-seedDemoData"])
        tap(app.buttons["Cast_FavoritesButton"])
        waitFor(navBar("Favorites"))
        waitFor(buttonWithLabel("Stub Channel 1"), "seeded favorite")
    }

    func testPlayBundledVideoShowsMiniPlayerWithControls() {
        launch()
        openMediaSources()
        tap(buttonWithLabel(bundledSample))
        waitForDisappearance(navBar("Media Sources"), "sheet closes when a channel is chosen")

        waitFor(app.otherElements["Cast_MiniPlayer"], "mini player")
        let title = app.staticTexts["Player_Title"]
        waitForLabel(title, containing: "Night Highway Drive")
        let playPause = app.buttons["Player_PlayPause"]
        waitForLabel(playPause, containing: "Pause")
        snapshot("08-mini-player-playing")

        tap(playPause)
        waitForLabel(playPause, containing: "Play")
        snapshot("09-mini-player-paused")
    }

    func testCarModeOpensCarPlayEmulator() {
        launch()
        let carMode = app.buttons["Cast_CarPlayModeButton"]
        scrollTo(carMode)
        tap(carMode)
        waitFor(navBar("CarPlay Emulator"), "car mode screen")
        snapshot("10-car-mode")
        tap(navBar("CarPlay Emulator").buttons["Done"])
        waitForDisappearance(navBar("CarPlay Emulator"))
    }

    func testBrowserOpensAndSendToCarConfirms() {
        launch()
        tap(app.buttons["Cast_BrowserRow"])
        waitFor(app.buttons["Browser_Exit"], "browser sheet")
        waitFor(app.textFields["Browser_AddressField"], "address bar")
        snapshot("11-browser")

        tap(app.buttons["Browser_SendToCar"])
        let alert = app.alerts.firstMatch
        waitFor(alert, "send-to-car feedback")
        snapshot("12-send-to-car")
        alert.buttons.firstMatch.tap()

        tap(app.buttons["Browser_Exit"])
        waitFor(app.buttons["Cast_BrowserRow"], "back on Cast")
    }

    func testHelpGuideOpens() {
        launch()
        tap(app.buttons["Cast_HelpButton"])
        waitFor(navBar("Car Display Setup"), "cast guide")
        snapshot("13-help")
        tap(navBar("Car Display Setup").buttons["Done"])
    }

    func testMirrorSheetOpens() {
        launch()
        tap(app.buttons["Cast_MirrorRow"])
        waitFor(navBar("Screen Mirroring"), "mirroring sheet")
        snapshot("14-mirror")
        tap(navBar("Screen Mirroring").buttons["Close"])
    }
}
