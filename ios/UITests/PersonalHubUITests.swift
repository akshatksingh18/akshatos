import XCTest

extension XCUIApplication {
    func openApps() { tabBars.buttons["Apps"].tap() }
    func openLegacyMenu() {
        openApps()
        buttons["open-personal-settings"].tap()
        let transition = buttons["fitness-transition"]
        for _ in 0..<6 where !transition.isHittable { swipeUp() }
        transition.tap()
    }
}

final class PersonalHubUITests: XCTestCase {
    func testFourTabsAndTaskCaptureWithoutFitnessNoise() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        XCTAssertFalse(app.buttons["open-squats"].exists)
        capture("Today · empty")
        app.tabBars.buttons["To-do"].tap()
        let input = app.textFields["todo-quick-add"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("Synthetic task tomorrow 5pm")
        app.buttons["todo-add"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic task"].waitForExistence(timeout: 5))
        capture("To-do · saved task")
    }
    func testJournalProtectedAndAppsHaveClearDestinations() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["journal-unlock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["journal-entry"].exists)
        capture("Journal · locked")
        app.openApps()
        capture("Apps")
        app.buttons["open-watchlist"].tap()
        XCTAssertTrue(app.navigationBars["Watchlist"].waitForExistence(timeout: 5))
        capture("Watchlist · empty")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["open-spending"].tap()
        XCTAssertTrue(app.navigationBars["Spending"].waitForExistence(timeout: 5))
        capture("Spending · empty")
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
