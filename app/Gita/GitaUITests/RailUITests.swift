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

    /// Choosing a verse should land on the page, not on a menu covering it.
    func testChoosingAVerseClosesTheRailAndThePanel() {
        app.buttons["Contents"].tap()
        XCTAssertTrue(app.buttons["chapter-2"].waitForExistence(timeout: 5))

        app.buttons["chapter-2"].tap()                       // expand
        let verse = app.buttons["Verse 2.47"]
        XCTAssertTrue(verse.waitForExistence(timeout: 5))
        verse.tap()

        // Did the panel go?
        XCTAssertFalse(app.buttons["chapter-1"].waitForExistence(timeout: 2), "panel stayed open")
        // Did the reader move?
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["verseReference"].label.contains("2.47"),
                      "reader did not move, showing \(app.staticTexts["verseReference"].label)")
        // Did the rail go? By where the page sits, not by hittability: the rail
        // stays in the hierarchy either way, and what actually changes is that
        // the page slides back to the screen's edge.
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 5))
        XCTAssertLessThan(app.buttons["menuButton"].frame.minX, 72,
                          "the page is still pushed aside, so the rail stayed open")
    }

    /// The verse number at the foot is no longer a second way into the contents.
    func testVerseReferenceDoesNotOpenTheContents() {
        app.buttons["Close menu"].firstMatch.tap()          // put the rail away
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 5),
                      "the reference should be plain text now, not a button")
        XCTAssertFalse(app.buttons["verseReference"].exists)
    }
}

/// Keeping a verse, seeing that it is kept, and finding it again.
final class BookmarkUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
    }

    private func openBookmarks() {
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.buttons["Bookmarks"].waitForExistence(timeout: 5))
        app.buttons["Bookmarks"].tap()
    }

    func testNothingKeptYet() {
        openBookmarks()
        XCTAssertTrue(app.staticTexts["Press and hold a verse to keep it"].waitForExistence(timeout: 5))
    }

    func testLongPressKeepsAVerseAndItAppearsInTheList() {
        // Press and hold the middle of the page.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(forDuration: 0.9)

        openBookmarks()
        XCTAssertTrue(app.buttons["bookmark-1.1"].waitForExistence(timeout: 5),
                      "the verse was not kept")
    }

    func testLongPressAgainRemovesIt() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(forDuration: 0.9)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(forDuration: 0.9)

        openBookmarks()
        XCTAssertTrue(app.staticTexts["Press and hold a verse to keep it"].waitForExistence(timeout: 5),
                      "the bookmark was not removed")
    }

    func testChoosingABookmarkOpensThatVerse() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(forDuration: 0.9)
        app.buttons["Next verse"].tap()                       // move away

        openBookmarks()
        XCTAssertTrue(app.buttons["bookmark-1.1"].waitForExistence(timeout: 5))
        app.buttons["bookmark-1.1"].tap()

        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["verseReference"].label.contains("1.1"),
                      "did not return to 1.1, showing \(app.staticTexts["verseReference"].label)")
    }
}
