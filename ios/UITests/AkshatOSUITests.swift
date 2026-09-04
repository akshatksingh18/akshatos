import XCTest

final class AkshatOSUITests: XCTestCase {
    func testHubOpensSquatsAndReturns() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["open-squats"].waitForExistence(timeout: 10))
        capture("AkshatOS hub")
        app.buttons["open-squats"].tap()
        XCTAssertTrue(app.buttons["log-set"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Start my day"].exists)
        capture("Squats dashboard")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["open-squats"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["open-pageVault"].exists)
        XCTAssertFalse(app.buttons["open-reelVault"].exists)
        app.buttons["open-squats"].tap()
        XCTAssertTrue(app.buttons["log-set"].waitForExistence(timeout: 5))
        app.buttons["Squat settings"].tap()
        XCTAssertTrue(app.navigationBars["Squat settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.steppers.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["notification-actions-help"].exists)
        XCTAssertTrue(app.buttons["export-squats-backup"].exists)
        XCTAssertTrue(app.buttons["restore-squats-backup"].exists)
        XCTAssertTrue(app.buttons["delete-squats-history"].exists)
        app.navigationBars["Squat settings"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["log-set"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
