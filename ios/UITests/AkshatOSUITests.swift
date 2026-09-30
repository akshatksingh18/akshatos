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
        XCTAssertTrue(app.buttons["open-liftLog"].exists, "Lift Log is an available module")
        XCTAssertTrue(app.buttons["open-body"].exists, "Body is an available module")
        XCTAssertFalse(app.buttons["open-reelVault"].exists, "ReelVault remains deferred")
        app.buttons["open-squats"].tap()
        XCTAssertTrue(app.buttons["log-set"].waitForExistence(timeout: 5))
        app.buttons["Pushup settings"].tap()
        XCTAssertTrue(app.navigationBars["Pushup settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.steppers.firstMatch.exists)
        XCTAssertTrue(app.steppers["Daily goal: 8 sets"].exists)
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

    /// Pushup history is one row on the dashboard and a screen of its own, so the dashboard does
    /// not grow with every day kept.
    func testHistoryOpensOnItsOwnScreen() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["open-squats"].waitForExistence(timeout: 10))
        app.buttons["open-squats"].tap()
        let history = app.buttons["open-pushups-history"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        for _ in 0..<5 where !history.isHittable { app.swipeUp() }
        XCTAssertTrue(history.isHittable)
        history.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["pushups-history-empty"].exists,
                      "A fresh install explains that days will appear here")
        capture("Pushup history")
        app.navigationBars["History"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["log-set"].waitForExistence(timeout: 5),
                      "Leaving history returns to the dashboard")
    }

    /// The hub's Backup row opens one screen that backs up or restores every module at once.
    /// Saving and picking folders go through system sheets, which the hosted tests cover instead.
    func testBackupOpensFromTheHub() {
        let app = XCUIApplication()
        app.launch()
        let entry = app.buttons["open-backup"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        for _ in 0..<4 where !entry.isHittable { app.swipeUp() }
        entry.tap()
        XCTAssertTrue(app.navigationBars["Backup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["backup-everything"].exists)
        XCTAssertTrue(app.buttons["restore-everything"].exists)
        capture("Backup")
        app.navigationBars["Backup"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["open-backup"].waitForExistence(timeout: 5), "Leaving Backup returns to the hub")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
