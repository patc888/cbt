import XCTest

final class ToolbarButtonSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBottomToolbarButtonsDoNotCrash() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let toolbarButtons = [
            "Home",
            "Insights",
            "Exercises",
            "Journal",
            "Settings",
            "Quick Add Mood",
            "Close mood options"
        ]

        for label in toolbarButtons {
            let button = app.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing toolbar button: \(label)")
            button.tap()
            XCTAssertEqual(app.state, .runningForeground, "App crashed after tapping \(label)")
        }

        let moodOptions = [
            "Very Low mood",
            "Low mood",
            "Neutral mood",
            "Good mood",
            "Great mood"
        ]

        for label in moodOptions {
            let addMood = app.buttons["Quick Add Mood"]
            XCTAssertTrue(addMood.waitForExistence(timeout: 8), "Missing quick-add button before \(label)")
            addMood.tap()

            let moodButton = app.buttons[label]
            XCTAssertTrue(moodButton.waitForExistence(timeout: 8), "Missing toolbar mood option: \(label)")
            moodButton.tap()
            XCTAssertEqual(app.state, .runningForeground, "App crashed after tapping \(label)")

            let dismissButton = app.buttons["Cancel"].firstMatch
            if dismissButton.waitForExistence(timeout: 8) {
                dismissButton.tap()
            } else {
                let closeButton = app.buttons["Close"].firstMatch
                XCTAssertTrue(closeButton.waitForExistence(timeout: 8), "Could not dismiss flow after tapping \(label)")
                closeButton.tap()
            }
        }
    }

    func testExerciseBottomNavigationDoesNotCrashOnRepeatedTaps() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let exercises = app.buttons["Exercises"]
        XCTAssertTrue(exercises.waitForExistence(timeout: 8))
        exercises.tap()

        let firstExercise = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Identify the Stressor.")
        ).firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 10))
        firstExercise.tap()

        let start = app.buttons["Start exercise"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.doubleTap()
        XCTAssertEqual(app.state, .runningForeground, "App crashed after repeated Start taps")

        let next = app.buttons["Go to next step"]
        if next.waitForExistence(timeout: 5) {
            next.doubleTap()
            XCTAssertEqual(app.state, .runningForeground, "App crashed after repeated Next taps")
        }

        let back = app.buttons["Go back to previous step"]
        if back.waitForExistence(timeout: 5) {
            back.doubleTap()
            XCTAssertEqual(app.state, .runningForeground, "App crashed after repeated Back taps")
        }
    }

    func testMoodCheckinStepButtonsDoNotCrashOnRepeatedTaps() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let addMood = app.buttons["Quick Add Mood"]
        XCTAssertTrue(addMood.waitForExistence(timeout: 8))
        addMood.tap()

        let neutralMood = app.buttons["Neutral mood"]
        XCTAssertTrue(neutralMood.waitForExistence(timeout: 8))
        neutralMood.tap()

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 8))
        continueButton.doubleTap()
        XCTAssertEqual(app.state, .runningForeground, "App crashed after repeated mood Continue taps")

        let previous = app.buttons["Previous step"]
        if previous.waitForExistence(timeout: 5) {
            previous.doubleTap()
            XCTAssertEqual(app.state, .runningForeground, "App crashed after repeated mood Previous taps")
        }
    }

    func testThoughtRecordStepButtonsDoNotCrashOnRepeatedTaps() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let thoughtRecord = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Thought Record")
        ).firstMatch
        XCTAssertTrue(thoughtRecord.waitForExistence(timeout: 10))
        thoughtRecord.tap()

        let firstTextView = app.textViews.firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 10))
        firstTextView.tap()
        firstTextView.typeText("A test situation")

        let next = app.buttons["Go to next step"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        next.doubleTap()
        XCTAssertEqual(app.state, .runningForeground, "App crashed after repeated thought-record Next taps")

        let back = app.buttons["Go back to previous step"]
        if back.waitForExistence(timeout: 5) {
            back.doubleTap()
            XCTAssertEqual(app.state, .runningForeground, "App crashed after repeated thought-record Back taps")
        }
    }
}
