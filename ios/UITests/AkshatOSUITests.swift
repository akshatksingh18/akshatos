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
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
