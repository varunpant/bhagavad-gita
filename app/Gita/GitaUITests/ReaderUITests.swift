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
        app.staticTexts["verseReference"]
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
            predicate: NSPredicate(format: "label == %@", expected),
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
        if english { app.launchArguments += ["-startInEnglish"] }
        app.launch()
        return app
    }

    func testStartsInSanskritAndShowsHindiWordMeanings() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
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
