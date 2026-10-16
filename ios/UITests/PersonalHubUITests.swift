import XCTest

extension XCUIApplication {
    func openApps() { let tab = tabBars.buttons["Apps"]; XCTAssertTrue(tab.waitForExistence(timeout: 10)); tab.tap() }
    func openLegacyMenu() {
        openApps()
        let settings = buttons["open-personal-settings"]; XCTAssertTrue(settings.waitForExistence(timeout: 5)); settings.tap()
        let transition = buttons["fitness-transition"]
        for _ in 0..<6 where !transition.isHittable { swipeUp() }
        transition.tap()
        XCTAssertTrue(navigationBars["WHOOP handover"].waitForExistence(timeout: 10))
    }
}

final class PersonalHubUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
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
    func testJournalStartsUnlockedAndAppsHaveClearDestinations() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.textViews["journal-entry"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["journal-unlock"].exists)
        capture("Journal · unlocked by default")
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
