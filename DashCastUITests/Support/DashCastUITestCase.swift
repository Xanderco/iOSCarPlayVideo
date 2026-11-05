import XCTest

/// Base class for DashCast UI tests.
///
/// Every test launches a fresh app with:
/// - `-uiTesting`   wipe persisted state + disable animations (tests are independent)
/// - `-stubNetwork` all http(s) goes to the in-app `StubNetwork` (no internet, no live streams)
/// - `-initialTab cast`
/// Extra arguments (e.g. `-seedDemoData`) are passed via `launch(extraArguments:)`.
///
/// Rules: never `sleep`; always `waitForExistence`/`waitFor(...)`. Screenshots are attached
/// with `.keepAlways` so CI artifacts show every screen.
class DashCastUITestCase: XCTestCase {
    var app: XCUIApplication!

    /// Generous upper bound for anything to appear; waits return as soon as the element exists.
    let timeout: TimeInterval = 20

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for label in ["Allow While Using App", "Allow Once", "Allow", "OK", "Don’t Allow", "Don't Allow", "Not Now"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            snapshot("zz-teardown-\(name)")
        }
        app?.terminate()
        app = nil
    }

    func launch(extraArguments: [String] = [], initialTab: String = "cast") {
        app.launchArguments = ["-uiTesting", "-stubNetwork", "-initialTab", initialTab] + extraArguments
        app.launchEnvironment["DASHCAST_UI_TESTS"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: timeout), "App did not reach foreground")
        XCTAssertTrue(app.buttons["Tab_Cast"].waitForExistence(timeout: timeout), "Tab bar did not appear")
    }

    // MARK: - Element helpers

    @discardableResult
    func waitFor(_ element: XCUIElement, _ message: @autoclosure () -> String = "",
                 file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let found = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(found, "Missing \(element). \(message())", file: file, line: line)
        return element
    }

    func waitForDisappearance(_ element: XCUIElement, _ message: String = "",
                              file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        let result = XCTWaiter().wait(for: [gone], timeout: timeout)
        XCTAssertEqual(result, .completed, "Still visible: \(element). \(message)", file: file, line: line)
    }

    func waitForLabel(_ element: XCUIElement, containing text: String,
                      file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) label never contained '\(text)' (was '\(element.exists ? element.label : "<missing>")')",
                       file: file, line: line)
    }

    /// Taps an element. Screens are wrapped in `accessibilityElement(children: .contain)`
    /// containers, which can make XCUITest report visible children as not hittable;
    /// fall back to tapping the element's centre.
    func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(element, file: file, line: line)
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    func button(_ identifierOrLabel: String) -> XCUIElement {
        app.buttons[identifierOrLabel].firstMatch
    }

    func buttonWithLabel(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func navBar(_ title: String) -> XCUIElement { app.navigationBars[title] }

    func openTab(_ tab: String, file: StaticString = #filePath, line: UInt = #line) {
        tap(app.buttons["Tab_\(tab)"], file: file, line: line)
        waitFor(app.otherElements["Screen_\(tab)"], "Screen for tab \(tab)", file: file, line: line)
    }

    /// Scrolls a container until `element` is hittable (bounded; no sleeps).
    func scrollTo(_ element: XCUIElement, in container: XCUIElement? = nil, maxSwipes: Int = 8) {
        let scroller = container ?? app.scrollViews.firstMatch
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            scroller.swipeUp()
            swipes += 1
        }
    }

    func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
