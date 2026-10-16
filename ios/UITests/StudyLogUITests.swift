import XCTest

final class StudyLogUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    func testFocusRotatesWithoutPausingAndReturnsToPortrait() {
        let device = XCUIDevice.shared
        device.orientation = .portrait
        defer { device.orientation = .portrait }
        let app = XCUIApplication(); app.launch()
        let focus = app.buttons["study-focus"]
        XCTAssertTrue(focus.waitForExistence(timeout: 10)); focus.tap()
        let toggle = app.buttons["study-focus-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.label != "Pause studying" { toggle.tap() }
        XCTAssertTrue(app.staticTexts["study-focus-block"].waitForExistence(timeout: 5))
        let keepAwake = app.switches["study-keep-awake"]
        XCTAssertTrue(keepAwake.waitForExistence(timeout: 5))
        for _ in 0..<3 where !keepAwake.isHittable { app.swipeUp() }
        keepAwake.tap()
        capture("Focus portrait · studying")
        device.orientation = .landscapeLeft
        XCTAssertTrue(app.otherElements["study-focus-landscape"].waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.label, "Pause studying", "Rotation cannot pause or replace the block")
        capture("Focus landscape · studying")
        device.orientation = .landscapeRight
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.label, "Pause studying")
        toggle.tap()
        XCTAssertFalse(app.staticTexts["study-focus-block"].exists)
        capture("Focus landscape · paused")
        app.buttons["study-focus-close"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        let portrait = NSPredicate { _, _ in app.frame.height > app.frame.width }
        expectation(for: portrait, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        app.buttons["study-focus"].tap()
        let reopenedSwitch = app.switches["study-keep-awake"]
        XCTAssertTrue(reopenedSwitch.waitForExistence(timeout: 5))
        XCTAssertEqual(reopenedSwitch.value as? String, "0", "Keep-awake is an explicit choice on each Focus entry")
        app.buttons["study-focus-close"].tap()
    }
    /// The hub opens Study Log on the countdown; Start runs a block, Pause keeps it, and history
    /// shows the week and the day. Locked-screen and relaunch behaviour are hosted tests and the phone.
    func testStudyLogStartsPausesAndShowsHistory() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        let toggle = app.buttons["study-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["study-studied"].exists, "Studied time sits under the countdown")
        capture("Study Log")

        toggle.tap()
        XCTAssertTrue(app.buttons["Pause studying"].waitForExistence(timeout: 5), "Start turns the button into Pause")
        XCTAssertTrue(app.staticTexts["study-current-block"].waitForExistence(timeout: 5),
                      "A running block shows its length")
        // Blocks under five seconds are treated as an accidental tap, so let this one run past that.
        sleep(6)
        capture("Study Log running")
        app.buttons["Pause studying"].tap()
        XCTAssertTrue(app.buttons["Resume studying"].waitForExistence(timeout: 5), "After a kept block the button resumes")
        XCTAssertFalse(app.staticTexts["study-current-block"].exists)

        let history = app.buttons["open-study-history"]
        for _ in 0..<3 where !history.isHittable { app.swipeUp() }
        history.tap()
        XCTAssertTrue(app.navigationBars["Study history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add a finished block"].exists, "History allows explicit corrections")
        capture("Study history")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
