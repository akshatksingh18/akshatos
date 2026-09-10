import XCTest

final class PageVaultUITests: XCTestCase {
    /// Simulator coverage stops at navigation and the empty library: importing a real PDF goes
    /// through the system document picker and belongs to the physical-device feasibility run.
    func testHubOpensPageVaultLibraryAndReturns() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["open-pageVault"].waitForExistence(timeout: 10))
        app.buttons["open-pageVault"].tap()

        XCTAssertTrue(app.buttons["import-pdf"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No books yet"].exists, "A fresh library states it is empty")
        XCTAssertFalse(app.staticTexts["pagevault-import-measurement"].exists,
                       "No import measurement is shown before anything is imported")
        capture("PageVault library")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["open-squats"].waitForExistence(timeout: 5),
                      "Leaving PageVault returns to the hub with Squats intact")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
