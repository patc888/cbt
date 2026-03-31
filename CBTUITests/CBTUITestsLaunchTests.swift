//
//  CBTUITestsLaunchTests.swift
//  CBTUITests
//
//  Created by Melissa Chan on 3/4/26.
//

import XCTest

final class CBTUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        #if targetEnvironment(macCatalyst)
        throw XCTSkip(
            "Manual verification only on Mac Catalyst in this environment: XCUI reaches the app, but accessibility snapshots expose only the top-level application node and do not reliably surface post-bootstrap Home elements."
        )
        #endif

        let app = XCUIApplication()
        app.launch()
        app.activate()

        let homeScreen = app.descendants(matching: .any).matching(identifier: "home-screen").firstMatch
        XCTAssertTrue(
            homeScreen.waitForExistence(timeout: 10),
            "Expected the post-bootstrap Home screen to appear after launch."
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
