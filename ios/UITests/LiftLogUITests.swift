import XCTest

final class LiftLogUITests: XCTestCase {
    func testHubOpensLiftLog() {
        let app = XCUIApplication()
        app.launch()
        let entry = app.buttons["open-liftLog"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            if entry.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(entry.isHittable)
        entry.tap()
        XCTAssertTrue(app.descendants(matching: .any)["lift-log-header"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Lift Log"].exists)
        XCTAssertTrue(app.buttons["start-lift-workout"].exists || app.buttons["add-lift-exercise"].exists)
    }
}
