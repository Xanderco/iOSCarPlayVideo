import XCTest

/// First-run onboarding: five pages, required passenger-safety acknowledgement, shown once.
final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // -UITests normally skips onboarding; -forceOnboarding resets and shows it.
        app.launchArguments += ["-UITests", "-forceOnboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testOnboardingRequiresSafetyAcknowledgementAndFinishes() throws {
        let continueButton = app.buttons["Onboarding_Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 15), "Onboarding did not appear")
        snapshot("onboarding-01")

        // Page 1 → 2 → 3 (safety).
        continueButton.tap()
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        snapshot("onboarding-02")
        continueButton.tap()

        let acknowledge = app.buttons["Onboarding_Acknowledge"]
        XCTAssertTrue(acknowledge.waitForExistence(timeout: 5), "Safety page missing")
        XCTAssertFalse(continueButton.isEnabled, "Continue must be disabled until the notice is acknowledged")
        snapshot("onboarding-03-safety")

        acknowledge.tap()
        XCTAssertTrue(continueButton.isEnabled, "Continue should enable after acknowledging")
        continueButton.tap()

        // Page 4 (privacy) → 5 (pay once).
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        snapshot("onboarding-04")
        continueButton.tap()

        let finish = app.buttons["Onboarding_Finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5), "Last page missing")
        XCTAssertTrue(app.buttons["Onboarding_SeePro"].exists, "Pro is optional; both choices must be offered")
        snapshot("onboarding-05")
        finish.tap()

        XCTAssertTrue(app.otherElements["Screen_Home"].waitForExistence(timeout: 10), "Did not land on Home")
        XCTAssertFalse(app.buttons["Onboarding_Finish"].exists, "Onboarding should be dismissed")
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
