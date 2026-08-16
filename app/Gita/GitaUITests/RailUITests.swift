//
//  RailUITests.swift
//  GitaUITests
//

import XCTest

/// The rail's icons must open their panels, not just close the rail — which is
/// what the old sheet-based wiring did.
final class RailUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash"]
        app.launch()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 10))
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5), "rail did not open")
    }

    func testSettingsIconOpensThePanelAndKeepsTheRail() {
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.switches["toggleTranslation"].waitForExistence(timeout: 5),
                      "settings panel did not open")
        XCTAssertTrue(app.buttons["Close settings"].exists,
                      "rail should still be there, with the gear now a cross")
    }

    func testContentsIconOpensThePanelAndKeepsTheRail() {
        app.buttons["Contents"].tap()

        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 5),
                      "contents panel did not open")
        XCTAssertTrue(app.buttons["Settings"].exists, "rail should still be there")
    }

    func testSearchIconOpensTheOverlayAndKeepsTheRail() {
        app.buttons["Search"].tap()

        XCTAssertTrue(app.textFields["searchField"].waitForExistence(timeout: 5),
                      "search overlay did not open")
        XCTAssertTrue(app.buttons["searchClose"].exists)
    }

    /// The verse number at the foot is no longer a second way into the contents.
    func testVerseReferenceDoesNotOpenTheContents() {
        app.buttons["Close menu"].firstMatch.tap()          // put the rail away
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 5),
                      "the reference should be plain text now, not a button")
        XCTAssertFalse(app.buttons["verseReference"].exists)
    }
}
