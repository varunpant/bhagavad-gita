//
//  ReaderUITests.swift
//  GitaUITests
//

import Foundation
import XCTest

/// The reader shows exactly one shloka at a time; these check that moving
/// between them actually works on device, not just that the view compiles.
final class ReaderUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private var referenceLabel: XCUIElement {
        app.buttons["verseReference"]
    }

    private var pager: XCUIElement {
        app.scrollViews.firstMatch
    }

    /// Paging is animated, so the reference changes a beat after the gesture.
    /// Poll for the expected value rather than reading it the instant the
    /// gesture returns — asserting immediately is a race, not a check.
    private func expectReference(
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            referenceLabel.waitForExistence(timeout: 10),
            "reader never appeared",
            file: file, line: line
        )
        let matched = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", expected),
            object: referenceLabel
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [matched], timeout: 5), .completed,
            "expected verse \(expected), showing \(referenceLabel.label)",
            file: file, line: line
        )
    }

    func testOpensAtTheFirstVerse() {
        expectReference("1.1")
    }

    func testNextButtonAdvancesOneVerse() {
        expectReference("1.1")
        app.buttons["Next verse"].tap()
        expectReference("1.2")
    }

    func testSwipeMovesForwardAndBack() {
        expectReference("1.1")
        pager.swipeLeft()
        expectReference("1.2")
        pager.swipeRight()
        expectReference("1.1")
    }

    func testCannotGoBackFromTheFirstVerse() {
        expectReference("1.1")
        XCTAssertFalse(app.buttons["Previous verse"].isEnabled)
    }
}

/// The language toggle flips the scripture and the word meanings together.
final class LanguageToggleUITests: XCTestCase {

    private func launch(english: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings"]
        if english { app.launchArguments += ["-startInEnglish"] }
        app.launch()
        return app
    }

    func testStartsInSanskritAndShowsHindiWordMeanings() {
        let app = launch()
        XCTAssertTrue(app.buttons["verseReference"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["शब्दार्थ"].exists, "Hindi word-meaning heading missing")
        XCTAssertFalse(app.staticTexts["WORD BY WORD"].exists)
    }

    func testTogglingSwitchesScriptureAndWordMeanings() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["शब्दार्थ"].waitForExistence(timeout: 10))

        app.buttons["languageToggle"].tap()

        let english = app.staticTexts["WORD BY WORD"]
        XCTAssertTrue(english.waitForExistence(timeout: 5), "did not switch to English")
        XCTAssertFalse(app.staticTexts["शब्दार्थ"].exists, "Hindi meanings still showing")

        app.buttons["languageToggle"].tap()
        XCTAssertTrue(app.staticTexts["शब्दार्थ"].waitForExistence(timeout: 5), "did not switch back")
    }

    func testEnglishModeShowsTransliterationNotDevanagari() {
        let app = launch(english: true)
        XCTAssertTrue(app.staticTexts["WORD BY WORD"].waitForExistence(timeout: 10))
        // The IAST replaces the Devanagari. Match on content rather than on an
        // exact line, since how the transliteration breaks is the model's choice.
        let iast = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "dhṛtarāṣṭra")
        ).firstMatch
        XCTAssertTrue(iast.exists, "transliteration missing")
        XCTAssertFalse(app.staticTexts["धृतराष्ट्र उवाच"].exists, "Devanagari still showing")
    }
}

/// Settings drives what the reader draws, and each block switches independently.
final class SettingsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
        app = XCUIApplication()
        app.launchArguments += ["-resetSettings"]
        app.launch()
        XCTAssertTrue(app.buttons["verseReference"].waitForExistence(timeout: 10))
    }

    private func openSettings() {
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    /// A SwiftUI `Form` is lazy: rows below the fold are not in the accessibility
    /// tree at all until they scroll into view. So scroll until the row appears
    /// rather than assuming the whole sheet is queryable.
    private func settingsToggle(_ identifier: String) -> XCUIElement {
        let element = app.switches[identifier]
        for _ in 0 ..< 6 where !element.exists {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 2), "\(identifier) never appeared")
        return element
    }

    /// Tapping the element's centre lands on the row's custom label, which does
    /// nothing. The control itself sits at the trailing edge.
    private func flip(_ identifier: String) {
        let toggle = settingsToggle(identifier)
        let before = toggle.value as? String
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertNotEqual(toggle.value as? String, before, "\(identifier) did not change")
    }

    private func closeSettings() {
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["verseReference"].waitForExistence(timeout: 5))
    }

    func testAllThreeBlocksShowByDefault() {
        XCTAssertTrue(app.staticTexts["अनुवाद"].exists)
        XCTAssertTrue(app.staticTexts["भावार्थ"].exists)
        XCTAssertTrue(app.staticTexts["शब्दार्थ"].exists)
    }

    /// The point of the setting: each block is independent, so turning one off
    /// must leave the other two alone.
    func testEachBlockCanBeHiddenIndependently() {
        openSettings()
        flip("toggleTranslation")
        closeSettings()

        XCTAssertFalse(app.staticTexts["अनुवाद"].exists, "translation should be hidden")
        XCTAssertTrue(app.staticTexts["भावार्थ"].exists, "meaning should be untouched")
        XCTAssertTrue(app.staticTexts["शब्दार्थ"].exists, "word list should be untouched")
    }

    func testTurningEverythingOffLeavesOnlyTheShloka() {
        openSettings()
        for identifier in ["toggleTranslation", "toggleMeaning", "toggleWordByWord"] {
            flip(identifier)
        }
        closeSettings()

        XCTAssertFalse(app.staticTexts["अनुवाद"].exists)
        XCTAssertFalse(app.staticTexts["भावार्थ"].exists)
        XCTAssertFalse(app.staticTexts["शब्दार्थ"].exists)
        XCTAssertTrue(app.buttons["verseReference"].exists, "the verse itself should remain")
    }

    /// Settings live in user.sqlite, so a choice has to survive a relaunch.
    func testChoiceSurvivesRelaunch() {
        openSettings()
        flip("toggleWordByWord")
        closeSettings()
        XCTAssertFalse(app.staticTexts["शब्दार्थ"].exists)

        app.terminate()
        app.launchArguments.removeAll { $0 == "-resetSettings" }
        app.launch()
        XCTAssertTrue(app.buttons["verseReference"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["शब्दार्थ"].exists, "setting did not persist")
    }
}

/// The contents sheet: reachable from the verse reference, searchable behind an
/// icon rather than a permanent field, and able to jump the reader anywhere.
final class ContentsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
        app = XCUIApplication()
        app.launchArguments += ["-resetSettings"]
        app.launch()
        XCTAssertTrue(app.buttons["verseReference"].waitForExistence(timeout: 10))
    }

    private func openContents() {
        app.buttons["verseReference"].tap()
        XCTAssertTrue(app.buttons["tocSearchToggle"].waitForExistence(timeout: 5), "contents did not open")
    }

    func testVerseReferenceOpensContents() {
        openContents()
        XCTAssertTrue(app.buttons["chapter-1"].exists)
        XCTAssertTrue(app.buttons["chapter-2"].exists)
    }

    /// The point of the icon: no search field until it is asked for.
    func testSearchFieldIsHiddenUntilTheIconIsTapped() {
        openContents()
        XCTAssertFalse(app.textFields["tocSearchField"].exists, "search field should not be visible at rest")

        app.buttons["tocSearchToggle"].tap()
        XCTAssertTrue(app.textFields["tocSearchField"].waitForExistence(timeout: 3))

        app.buttons["tocSearchToggle"].tap()
        XCTAssertFalse(app.textFields["tocSearchField"].exists, "search field should collapse again")
    }

    func testSearchFindsVersesByEnglishText() {
        openContents()
        app.buttons["tocSearchToggle"].tap()
        let field = app.textFields["tocSearchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("kurukshetra")

        let firstResult = app.staticTexts["1.1"]
        XCTAssertTrue(firstResult.waitForExistence(timeout: 5), "no results for a term that is in the text")
        XCTAssertFalse(app.buttons["chapter-5"].exists, "chapter list should be replaced by results")
    }

    func testChoosingAVerseMovesTheReader() {
        openContents()
        app.buttons["chapter-2"].tap()
        let verse = app.buttons["Verse 2.47"]
        XCTAssertTrue(verse.waitForExistence(timeout: 5), "verse grid did not appear")
        verse.tap()

        let reference = app.buttons["verseReference"]
        XCTAssertTrue(reference.waitForExistence(timeout: 5))
        let matched = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "2.47"), object: reference
        )
        XCTAssertEqual(XCTWaiter().wait(for: [matched], timeout: 5), .completed,
                       "reader did not move to 2.47, showing \(reference.label)")
    }
}
