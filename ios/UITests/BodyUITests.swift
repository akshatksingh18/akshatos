import XCTest

final class BodyUITests: XCTestCase {
    /// The hub opens Body; the measurement form lists every site with its guidance; history and
    /// photos are reachable and explain an empty state. Typing values and the camera are left to
    /// hosted tests and the phone.
    func testBodyOpensWithWeightMeasurementsPhotosAndHistory() {
        let app = XCUIApplication()
        app.launch()
        let entry = app.buttons["open-body"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        for _ in 0..<4 where !entry.isHittable { app.swipeUp() }
        entry.tap()

        XCTAssertTrue(app.navigationBars["Body"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["body-weight-field"].exists)
        XCTAssertTrue(app.buttons["log-weight"].exists)
        capture("Body")

        let measure = app.buttons["measure-body"]
        for _ in 0..<3 where !measure.isHittable { app.swipeUp() }
        measure.tap()
        XCTAssertTrue(app.navigationBars["Measure"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["body-site-waistNavel"].exists, "The first site is the waist at the navel")
        XCTAssertTrue(app.staticTexts["Level around the belly button, relaxed, after a normal breath out."].exists,
                      "Each site says where the tape goes")
        capture("Body measure")
        app.navigationBars["Measure"].buttons["Cancel"].tap()

        let history = app.buttons["open-body-history"]
        for _ in 0..<4 where !history.isHittable { app.swipeUp() }
        history.tap()
        XCTAssertTrue(app.staticTexts["body-history-empty"].waitForExistence(timeout: 5))
        app.navigationBars["History"].buttons.element(boundBy: 0).tap()

        let photos = app.buttons["open-body-photos"]
        for _ in 0..<4 where !photos.isHittable { app.swipeUp() }
        photos.tap()
        XCTAssertTrue(app.staticTexts["body-photos-empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["choose-body-photo"].exists)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
