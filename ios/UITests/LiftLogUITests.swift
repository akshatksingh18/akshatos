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
        let upper = app.buttons["start-upper-workout"].firstMatch
        XCTAssertTrue(upper.waitForExistence(timeout: 5))
        upper.tap()
        XCTAssertTrue(app.staticTexts["Weighted pull-ups"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Last performance: none yet for this exercise and measurement mode."].exists)
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
