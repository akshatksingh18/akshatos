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

    /// The file mover and importer are system UI, so this covers what the app owns: the sheet is
    /// reachable from an empty library, as after a clean install, and exporting nothing explains itself.
    func testBackupSheetOffersExportAndRestore() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["open-pageVault"].waitForExistence(timeout: 10))
        app.buttons["open-pageVault"].tap()

        XCTAssertTrue(app.buttons["pagevault-backup"].waitForExistence(timeout: 10))
        app.buttons["pagevault-backup"].tap()
        XCTAssertTrue(app.buttons["pagevault-export-full"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pagevault-export-data"].exists)
        XCTAssertTrue(app.buttons["pagevault-restore"].exists,
                      "Restore is reachable before any book exists")
        capture("PageVault backup")

        app.buttons["pagevault-export-full"].tap()
        XCTAssertTrue(app.staticTexts["There are no books to export yet."].waitForExistence(timeout: 5),
                      "Exporting an empty library says so instead of producing an empty folder")
        app.alerts.buttons["OK"].tap()
        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["import-pdf"].waitForExistence(timeout: 5),
                      "Closing the sheet returns to the library")
    }

    func testTakeawaysIsReachableAndEmptyUntilSomethingIsKept() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["open-pageVault"].waitForExistence(timeout: 10))
        app.buttons["open-pageVault"].tap()

        XCTAssertTrue(app.buttons["open-takeaways"].waitForExistence(timeout: 10))
        app.buttons["open-takeaways"].tap()

        XCTAssertTrue(app.staticTexts["Nothing kept yet"].waitForExistence(timeout: 5),
                      "With nothing highlighted, Takeaways says so rather than showing an empty list")
        capture("PageVault takeaways")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["import-pdf"].waitForExistence(timeout: 5),
                      "Leaving Takeaways returns to the library")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
