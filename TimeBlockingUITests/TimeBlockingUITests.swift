//
//  TimeBlockingUITests.swift
//  TimeBlockingUITests
//
//  Created by Melissa Chan on 3/7/26.
//

import XCTest

final class TimeBlockingUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = configuredApp()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testPrimaryButtonsDoNotCrash() throws {
        let app = configuredApp()
        app.launch()
        ensureMainWindowVisible(in: app)

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 20))

        tapIfPresent(app.buttons["statsButton"])
        tapIfPresent(app.buttons["closeStatsButton"])

        tapIfPresent(app.buttons["settingsButton"])
        tapIfPresent(app.buttons["closeSettingsButton"])

        tapIfPresent(app.buttons["addBlockButton"])
        tapIfPresent(app.buttons["Cancel"])

        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            configuredApp().launch()
        }
    }

    @MainActor
    private func configuredApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["TIMEBLOCKING_FORCE_NO_CLOUDKIT"] = "1"
        return app
    }

    @MainActor
    private func tapIfPresent(_ element: XCUIElement) {
        guard element.waitForExistence(timeout: 5), element.isHittable else {
            return
        }

        element.tap()
    }

    @MainActor
    private func ensureMainWindowVisible(in app: XCUIApplication) {
        #if os(macOS)
        guard !app.buttons["settingsButton"].waitForExistence(timeout: 2) else {
            return
        }

        app.activate()
        app.typeKey("n", modifierFlags: [.command])
        #endif
    }
}
