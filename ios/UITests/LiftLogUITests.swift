import XCTest

final class LiftLogUITests: XCTestCase {
    func testHubOpensLiftLog() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["open-liftLog"].waitForExistence(timeout: 10))
        let entry = app.staticTexts["Lift Log"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            if entry.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(entry.isHittable)
        entry.tap()
        XCTAssertTrue(app.descendants(matching: .any)["lift-log-header"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Lift Log"].exists)
        let start = app.buttons["start-lift-workout"]
        XCTAssertTrue(start.exists)
        start.tap()
        XCTAssertTrue(app.buttons["start-empty-workout"].waitForExistence(timeout: 5),
                      "An empty workout is offered beside the splits")
        let backDay = app.buttons["Back and biceps day"].firstMatch
        XCTAssertTrue(backDay.waitForExistence(timeout: 5))
        backDay.tap()
        XCTAssertTrue(app.staticTexts["Weighted pull-ups"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Last performance: none yet for this exercise and measurement mode."].exists)

        let add = app.buttons["add-workout-exercise"]
        for _ in 0..<6 where !add.isHittable { app.swipeUp() }
        add.tap()
        let name = app.textFields["lift-exercise-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Hammer curl")
        app.buttons["save-lift-exercise"].tap()
        XCTAssertTrue(app.staticTexts["Hammer curl"].waitForExistence(timeout: 5),
                      "An exercise added during the workout appears in it")
        capture("Lift Log workout")
    }

    /// Splits are their own screen: the starting three are listed and each opens its editor.
    func testSplitsOpenAndShowTheirExercises() {
        let app = XCUIApplication()
        app.launch()
        let entry = app.staticTexts["Lift Log"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        for _ in 0..<4 where !entry.isHittable { app.scrollViews.firstMatch.swipeUp() }
        entry.tap()
        let splits = app.buttons["open-lift-splits"]
        XCTAssertTrue(splits.waitForExistence(timeout: 10))
        for _ in 0..<6 where !splits.isHittable { app.swipeUp() }
        splits.tap()
        XCTAssertTrue(app.navigationBars["Splits"].waitForExistence(timeout: 5))
        for day in ["Lower day", "Back and biceps day", "Chest day"] {
            XCTAssertTrue(row(app, day).exists, "\(day) is listed")
        }
        XCTAssertTrue(app.buttons["add-lift-split"].exists)
        capture("Lift splits")
        row(app, "Chest day").tap()
        XCTAssertTrue(app.navigationBars["Edit split"].waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, "Dumbbell bench press").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["add-split-exercise"].exists)
        app.navigationBars["Edit split"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Splits"].waitForExistence(timeout: 5))
    }

    /// A list row that is a button reads as one element, labelled with all of its text.
    private func row(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// History is one row on the main screen and a screen of its own holding every workout.
    func testHistoryOpensOnItsOwnScreen() {
        let app = XCUIApplication()
        app.launch()
        let entry = app.staticTexts["Lift Log"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        for _ in 0..<4 where !entry.isHittable { app.scrollViews.firstMatch.swipeUp() }
        entry.tap()
        let history = app.buttons["open-lift-history"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        for _ in 0..<4 where !history.isHittable { app.swipeUp() }
        history.tap()
        XCTAssertTrue(app.navigationBars["Lift history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["lift-history-empty"].exists,
                      "With nothing finished, history explains itself")
        app.navigationBars["Lift history"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.descendants(matching: .any)["lift-log-header"].waitForExistence(timeout: 5))
    }
}
