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
}
