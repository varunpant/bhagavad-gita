//
//  RailUITests.swift
//  GitaUITests
//

import XCTest

/// The rail's icons must open their panels, not just close the rail — which is
/// what the old sheet-based wiring did.
@MainActor
final class RailUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() async throws {
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
        // The rail keeps its own icons now — the gear stays a gear and wears a
        // ring — so the rail is proved by the gear still being there, and the
        // way out by the panel's own cross.
        XCTAssertTrue(app.buttons["Settings"].exists, "the rail went away")
        XCTAssertTrue(app.buttons["Close settings"].exists, "the panel has no way out")
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
@MainActor
final class BookmarkUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
    }

    /// The empty state follows the reading language, and the app starts in
    /// Sanskrit — see the language rules in app/CLAUDE.md.
    private static let emptyState = "श्लोक संख्या के पास बुकमार्क दबाकर उसे सहेजें"

    private func openBookmarks() {
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.buttons["Bookmarks"].waitForExistence(timeout: 5))
        app.buttons["Bookmarks"].tap()
    }

    func testNothingKeptYet() {
        openBookmarks()
        XCTAssertTrue(app.staticTexts[Self.emptyState].waitForExistence(timeout: 5))
    }

    func testBookmarkButtonKeepsAVerseAndItAppearsInTheList() {
        app.buttons["bookmarkButton"].tap()

        openBookmarks()
        XCTAssertTrue(app.buttons["bookmark-1.1"].waitForExistence(timeout: 5),
                      "the verse was not kept")
    }

    func testTappingAgainRemovesIt() {
        app.buttons["bookmarkButton"].tap()
        app.buttons["bookmarkButton"].tap()

        openBookmarks()
        XCTAssertTrue(app.staticTexts[Self.emptyState].waitForExistence(timeout: 5),
                      "the bookmark was not removed")
    }

    /// Removing one from the panel.
    ///
    /// This path had no test, which is how it shipped broken: the row carried
    /// `.swipeActions`, which only exists inside a `List`, so on a `LazyVStack`
    /// it compiled and did nothing and the panel had no way to remove anything.
    func testABookmarkCanBeRemovedFromThePanel() {
        app.buttons["bookmarkButton"].tap()
        openBookmarks()

        let row = app.buttons["bookmark-1.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 1.2)

        // The suite reads in Sanskrit, and the menu follows the reading
        // language like everything else the reader meets.
        let remove = app.buttons["हटाएँ"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "no way to remove it")
        remove.tap()

        XCTAssertTrue(app.staticTexts[Self.emptyState].waitForExistence(timeout: 5),
                      "the bookmark survived being removed")
    }

    func testChoosingABookmarkOpensThatVerse() {
        app.buttons["bookmarkButton"].tap()
        app.buttons["Next verse"].tap()                       // move away

        openBookmarks()
        XCTAssertTrue(app.buttons["bookmark-1.1"].waitForExistence(timeout: 5))
        app.buttons["bookmark-1.1"].tap()

        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["verseReference"].label.contains("1.1"),
                      "did not return to 1.1, showing \(app.staticTexts["verseReference"].label)")
    }
}

/// The rail's own state: which panel you are in, and how you get out of it.
@MainActor
final class RailSelectionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash"]
        app.launch()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 10))
        app.buttons["menuButton"].tap()
    }

    /// The open panel's icon is marked selected, and only that one.
    func testTheOpenPanelsIconIsTheSelectedOne() {
        XCTAssertTrue(app.buttons["Progress"].waitForExistence(timeout: 5))
        app.buttons["Progress"].tap()

        XCTAssertTrue(app.buttons["Progress"].isSelected, "the open panel is not marked selected")
        XCTAssertFalse(app.buttons["Bookmarks"].isSelected, "a closed panel is marked selected")
    }

    /// Nothing is selected before a panel is opened.
    func testNothingIsSelectedWithNoPanelOpen() {
        XCTAssertTrue(app.buttons["Contents"].waitForExistence(timeout: 5))
        for panel in ["Contents", "Bookmarks", "Progress", "Settings"] {
            XCTAssertFalse(app.buttons[panel].isSelected, "\(panel) is selected with no panel open")
        }
    }

    /// Every panel closes from its own corner, at the same size and place.
    func testEveryPanelClosesFromItsOwnCross() {
        for (panel, label) in [("Contents", "Close contents"), ("Bookmarks", "Close bookmarks"),
                               ("Progress", "Close progress"), ("Settings", "Close settings")] {
            XCTAssertTrue(app.buttons[panel].waitForExistence(timeout: 5))
            app.buttons[panel].tap()

            let cross = app.buttons[label]
            XCTAssertTrue(cross.waitForExistence(timeout: 5), "\(panel) has no cross")
            // Top right of the panel, not the far left where the rail is.
            XCTAssertGreaterThan(cross.frame.minX, app.buttons[panel].frame.maxX,
                                 "\(panel)'s cross is not on the panel side")
            cross.tap()
            XCTAssertFalse(cross.waitForExistence(timeout: 2), "\(panel) stayed open")
        }
    }
}

/// Help on the rail, and the welcome behind it in Settings.
@MainActor
final class RailHelpUITests: XCTestCase {

    /// The rail is where a reader looks for help, and what they find there is
    /// the reference — not the nine-page introduction, which used to be here.
    func testTheHelpIconOpensTheHelpPanel() {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish"]
        app.launch()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 15))
        app.buttons["menuButton"].tap()

        XCTAssertTrue(app.buttons["Help"].waitForExistence(timeout: 5), "no help on the rail")
        app.buttons["Help"].tap()

        XCTAssertTrue(app.staticTexts["Reading a verse"].waitForExistence(timeout: 10),
                      "the help panel did not open")

        // The welcome is emphatically not what the rail opens any more.
        XCTAssertFalse(app.buttons["welcomeAdvance"].exists)

        // And the panel is written in whichever script the rail's own switch is
        // set to — it carries no second one. This is the rule in
        // `app/CLAUDE.md`: exactly one language switcher, and it is that button.
        app.buttons["languageToggle"].tap()
        XCTAssertTrue(app.staticTexts["श्लोक पढ़ना"].waitForExistence(timeout: 5),
                      "the help panel did not follow the rail's script switch")
        XCTAssertFalse(app.staticTexts["Reading a verse"].exists)
    }

    /// The introduction kept its way back, one door along: Settings, under
    /// About, where a reader looks for a thing they saw once.
    func testSettingsOpensTheWelcome() {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish", "-openSettings"]
        app.launch()

        let guideRow = app.buttons["showGuide"]
        XCTAssertTrue(guideRow.waitForExistence(timeout: 15), "no welcome tour in Settings")
        guideRow.tap()

        XCTAssertTrue(app.buttons["welcomeAdvance"].waitForExistence(timeout: 10),
                      "the welcome did not open")
        XCTAssertTrue(app.buttons["welcomeLanguage-english"].exists)
    }
}
