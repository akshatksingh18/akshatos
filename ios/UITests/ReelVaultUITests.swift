import XCTest

final class ReelVaultUITests: XCTestCase {
    /// Simulator coverage stops at navigation and the empty states: picking a video goes through
    /// the system photo and file pickers, and playback needs a real video, so both are phone checks.
    func testHubOpensReelVaultAndItsLibrary() {
        let app = XCUIApplication()
        app.launch()
        let entry = app.buttons["open-reelVault"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "ReelVault is an available module")
        for _ in 0..<4 where !entry.isHittable { app.swipeUp() }
        entry.tap()

        XCTAssertTrue(app.navigationBars["ReelVault"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No videos yet"].exists, "A fresh library says it is empty")
        XCTAssertTrue(app.buttons["add-reels-photos"].exists)
        XCTAssertTrue(app.buttons["add-reels-files"].exists)
        capture("ReelVault")

        app.buttons["open-reel-library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["reel-library-empty"].exists)
        XCTAssertTrue(app.buttons["restore-reels"].exists)
        XCTAssertFalse(app.buttons["export-reels"].isEnabled, "There is nothing to back up yet")
        capture("ReelVault library")

        app.navigationBars["Library"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["ReelVault"].waitForExistence(timeout: 5))
        app.navigationBars["ReelVault"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["open-squats"].waitForExistence(timeout: 5),
                      "Leaving ReelVault returns to the hub")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
