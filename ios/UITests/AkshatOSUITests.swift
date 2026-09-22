import XCTest

final class AkshatOSUITests: XCTestCase {
    func testHubOpensPushupReminderAndReturns() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["open-squats"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["akshatos-homebase"].exists)
        XCTAssertTrue(app.buttons["open-squats"].label.contains("Pushup Reminder"))
        capture("AkshatOS hub")
        app.buttons["open-squats"].tap()
        XCTAssertTrue(app.buttons["log-set"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Start my day"].exists)
        XCTAssertFalse(app.buttons["Remind me in 10 min"].exists)
        XCTAssertFalse(app.buttons["End my day"].exists)
        capture("Pushup dashboard")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["open-squats"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["open-pageVault"].exists, "PageVault is an available module")
        XCTAssertFalse(app.buttons["open-reelVault"].exists, "ReelVault remains deferred")
        app.buttons["open-squats"].tap()
        XCTAssertTrue(app.buttons["log-set"].waitForExistence(timeout: 5))
        app.buttons["Pushup settings"].tap()
        XCTAssertTrue(app.navigationBars["Pushup settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.steppers.firstMatch.exists)
        XCTAssertTrue(app.steppers["Daily quest: 8 pushup sets"].exists)
        XCTAssertTrue(app.staticTexts["notification-permission-status"].exists)
        XCTAssertTrue(app.staticTexts["notification-permission-caveats"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.buttons["export-pushups-backup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["restore-pushups-backup"].exists)
        XCTAssertTrue(app.buttons["delete-pushups-history"].exists)
        app.swipeUp()
        XCTAssertTrue(app.buttons["set-home-location"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home-automation-status"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["notification-actions-help"].waitForExistence(timeout: 5))
        app.navigationBars["Pushup settings"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["log-set"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
