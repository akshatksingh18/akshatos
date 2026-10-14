import XCTest

final class StudyLogUITests: XCTestCase {
    /// The hub opens Study Log on the countdown; Start runs a block, Pause keeps it, and history
    /// shows the week and the day. Locked-screen and relaunch behaviour are hosted tests and the phone.
    func testStudyLogStartsPausesAndShowsHistory() {
        let app = XCUIApplication()
        app.launch()
        let entry = app.buttons["open-studyLog"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        for _ in 0..<4 where !entry.isHittable { app.swipeUp() }
        entry.tap()

        XCTAssertTrue(app.navigationBars["Study Log"].waitForExistence(timeout: 10))
        let toggle = app.buttons["study-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["study-studied"].exists, "Studied time sits under the countdown")
        capture("Study Log")

        toggle.tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5), "Start turns the button into Pause")
        XCTAssertTrue(app.staticTexts["study-current-block"].waitForExistence(timeout: 5),
                      "A running block shows its length")
        // Blocks under five seconds are treated as an accidental tap, so let this one run past that.
        sleep(6)
        capture("Study Log running")
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5), "After a kept block the button resumes")
        XCTAssertFalse(app.staticTexts["study-current-block"].exists)

        let history = app.buttons["open-study-history"]
        for _ in 0..<3 where !history.isHittable { app.swipeUp() }
        history.tap()
        XCTAssertTrue(app.navigationBars["Study history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["study-week"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["study-history-empty"].exists, "The block just kept is in history")
        capture("Study history")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
