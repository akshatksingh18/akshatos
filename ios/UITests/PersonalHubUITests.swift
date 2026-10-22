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
    func testStudyExchangeLivesInSettingsWithoutAnotherTab() {
        let app = XCUIApplication(); app.launch(); app.openApps()
        app.buttons["open-personal-settings"].tap()
        let folder = app.buttons["Linked folder"]
        for _ in 0..<7 where !folder.isHittable { app.swipeUp() }
        XCTAssertTrue(folder.isHittable); folder.tap()
        let manual = app.buttons["Import laptop file…"]
        for _ in 0..<8 where !manual.isHittable { app.swipeUp() }
        XCTAssertTrue(manual.isHittable)
        XCTAssertEqual(app.tabBars.buttons.count, 3)
    }
    func testThreeTabsAndTaskCaptureWithoutFitnessOrJournalNoise() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.count, 3)
        XCTAssertFalse(app.buttons["open-squats"].exists)
        XCTAssertFalse(app.tabBars.buttons["Journal"].exists)
        capture("Today · empty")
        app.tabBars.buttons["To-do"].tap()
        let input = app.textFields["todo-quick-add"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("Synthetic task tomorrow 5pm")
        app.buttons["todo-add"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic task"].waitForExistence(timeout: 5))
        capture("To-do · saved task")
    }
    func testAppsHaveClearDestinationsWithoutJournal() {
        let app = XCUIApplication(); app.launch()
        XCTAssertFalse(app.tabBars.buttons["Journal"].exists)
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
    func testSettingsAndSearchHaveNoJournalOrFullDayRequirement() {
        let app = XCUIApplication(); app.launch(); app.openApps()
        app.buttons["Search"].tap()
        XCTAssertTrue(app.staticTexts["Find a task or parked thought."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Unlock Journal to search its entries"].exists)
        app.buttons["Close"].tap()
        app.buttons["open-personal-settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings & backup"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Journal privacy"].exists)
        XCTAssertFalse(app.switches["Daily Journal invitation"].exists)
        XCTAssertFalse(app.switches["Optional full-day challenge"].exists)
        capture("Settings · no Journal")
    }
    func testDailyRoutineCreateCheckAndUndoWithoutAnotherTab() {
        let app = XCUIApplication(); app.launch()
        let manage = app.buttons["routine-manage"]
        for _ in 0..<7 where !manage.isHittable { app.swipeUp() }
        XCTAssertTrue(manage.waitForExistence(timeout: 5)); manage.tap()
        app.buttons["routine-add"].tap()
        let title = app.textFields["routine-title"].firstMatch
        if title.exists { title.tap(); title.typeText("Synthetic routine check") }
        else {
            let multiline = app.textViews["routine-title"]; XCTAssertTrue(multiline.waitForExistence(timeout: 5))
            multiline.tap(); multiline.typeText("Synthetic routine check")
        }
        app.buttons["routine-save"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic routine check"].waitForExistence(timeout: 5))
        capture("Daily routine · manage")
        app.navigationBars["Daily routine"].buttons["Done"].tap()
        let check = app.buttons["routine-check-Synthetic routine check"]
        for _ in 0..<6 where !check.isHittable { app.swipeUp() }
        XCTAssertTrue(check.waitForExistence(timeout: 5)); check.tap()
        XCTAssertEqual(check.value as? String, "done")
        capture("Daily routine · checked")
        check.tap()
        XCTAssertEqual(check.value as? String, "pending")
        XCTAssertEqual(app.tabBars.buttons.count, 3)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
