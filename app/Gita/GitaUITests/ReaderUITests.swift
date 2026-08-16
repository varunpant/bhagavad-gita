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
        // -resetSettings matters here as much as anywhere: the reader now
        // resumes where it left off, so without it these tests inherit the
        // position an earlier test walked to and never see 1.1.
        app.launchArguments += ["-resetSettings", "-skipSplash"]
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
        app.launchArguments += ["-resetSettings", "-skipSplash"]
        if english { app.launchArguments += ["-startInEnglish"] }
        app.launch()
        return app
    }

    func testStartsInSanskritAndShowsHindiHeadings() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["अनुवाद"].exists, "Hindi translation heading missing")
        XCTAssertFalse(app.staticTexts["TRANSLATION"].exists)
    }

    func testTogglingSwitchesScriptureAndHeadings() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["अनुवाद"].waitForExistence(timeout: 10))

        app.buttons["menuButton"].tap()
        app.buttons["languageToggle"].tap()
        app.buttons["Close menu"].firstMatch.tap()

        let english = app.staticTexts["TRANSLATION"]
        XCTAssertTrue(english.waitForExistence(timeout: 5), "did not switch to English")
        XCTAssertFalse(app.staticTexts["अनुवाद"].exists, "Hindi headings still showing")

        app.buttons["menuButton"].tap()
        app.buttons["languageToggle"].tap()
        app.buttons["Close menu"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["अनुवाद"].waitForExistence(timeout: 5), "did not switch back")
    }

    func testEnglishModeShowsTransliterationNotDevanagari() {
        let app = launch(english: true)
        XCTAssertTrue(app.staticTexts["TRANSLATION"].waitForExistence(timeout: 10))
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
        app.launchArguments += ["-resetSettings", "-skipSplash"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
    }

    /// Settings is a panel beside the rail now, not a sheet: there is no Done
    /// button, and its rail icon becomes the close control while it is up.
    private func openSettings() {
        app.buttons["menuButton"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["toggleTranslation"].waitForExistence(timeout: 5),
                      "settings did not open")
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
        app.buttons["Close settings"].tap()
        app.buttons["Close menu"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 5))
    }

    /// Translation and meaning are the reading experience; word-by-word is
    /// study material and opt-in.
    func testTranslationAndMeaningShowByDefaultButNotWordByWord() {
        XCTAssertTrue(app.staticTexts["अनुवाद"].exists, "translation should be on by default")
        XCTAssertTrue(app.staticTexts["भावार्थ"].exists, "meaning should be on by default")
        XCTAssertFalse(app.staticTexts["शब्दार्थ"].exists, "word-by-word should be off by default")
    }

    /// The point of the setting: each block is independent, so turning one off
    /// must leave the other two alone.
    func testEachBlockCanBeHiddenIndependently() {
        openSettings()
        flip("toggleTranslation")
        closeSettings()

        XCTAssertFalse(app.staticTexts["अनुवाद"].exists, "translation should be hidden")
        XCTAssertTrue(app.staticTexts["भावार्थ"].exists, "meaning should be untouched")
    }

    func testTurningEverythingOffLeavesOnlyTheShloka() {
        openSettings()
        // Word-by-word starts off, so only the two on by default need flipping.
        for identifier in ["toggleTranslation", "toggleMeaning"] {
            flip(identifier)
        }
        closeSettings()

        XCTAssertFalse(app.staticTexts["अनुवाद"].exists)
        XCTAssertFalse(app.staticTexts["भावार्थ"].exists)
        XCTAssertFalse(app.staticTexts["शब्दार्थ"].exists)
        XCTAssertTrue(app.staticTexts["verseReference"].exists, "the verse itself should remain")
    }

    /// Settings live in user.sqlite, so a choice has to survive a relaunch — in
    /// both directions, since turning a default-on setting off and a default-off
    /// setting on are stored identically but fail differently.
    func testChoicesSurviveRelaunch() {
        openSettings()
        flip("toggleWordByWord")     // off by default -> on
        flip("toggleMeaning")        // on by default  -> off
        closeSettings()
        XCTAssertTrue(app.staticTexts["शब्दार्थ"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["भावार्थ"].exists)

        app.terminate()
        app.launchArguments.removeAll { $0 == "-resetSettings" }
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))

        XCTAssertTrue(app.staticTexts["शब्दार्थ"].waitForExistence(timeout: 5),
                      "word-by-word was switched on but did not persist")
        XCTAssertFalse(app.staticTexts["भावार्थ"].exists,
                       "meaning was switched off but came back")
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
        app.launchArguments += ["-resetSettings", "-skipSplash"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
    }

    /// The contents is reached from the rail. It used to open by tapping the
    /// verse number, which was a second, hidden way in; RailUITests asserts
    /// that route is gone.
    private func openContents() {
        app.buttons["menuButton"].tap()
        app.buttons["Contents"].tap()
        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 5), "contents did not open")
    }

    func testContentsListsEveryChapter() {
        openContents()
        XCTAssertTrue(app.buttons["chapter-1"].exists)
        XCTAssertTrue(app.buttons["chapter-18"].exists)
    }

    func testChoosingAVerseMovesTheReader() {
        openContents()
        app.buttons["chapter-2"].tap()
        let verse = app.buttons["Verse 2.47"]
        XCTAssertTrue(verse.waitForExistence(timeout: 5), "verse grid did not appear")
        verse.tap()

        let reference = app.staticTexts["verseReference"]
        XCTAssertTrue(reference.waitForExistence(timeout: 5))
        let matched = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "2.47"), object: reference
        )
        XCTAssertEqual(XCTWaiter().wait(for: [matched], timeout: 5), .completed,
                       "reader did not move to 2.47, showing \(reference.label)")
    }
}

/// The contents has its own language switch, seeded from the reader's but not
/// tied to it.
final class ContentsLanguageUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
        app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
    }

    private func openContents() {
        app.buttons["menuButton"].tap()
        app.buttons["Contents"].tap()
        XCTAssertTrue(app.buttons["tocLanguageToggle"].waitForExistence(timeout: 5))
    }

    func testContentsOpensInTheReadersLanguage() {
        openContents()
        // Reader defaults to Sanskrit, so the contents should too.
        XCTAssertTrue(app.staticTexts["अध्याय"].exists, "contents did not open in Sanskrit")
    }

    func testTogglingSwitchesTheChapterNames() {
        openContents()
        XCTAssertTrue(app.staticTexts["अध्याय"].exists)

        app.buttons["tocLanguageToggle"].tap()
        XCTAssertTrue(app.staticTexts["CHAPTERS"].waitForExistence(timeout: 3), "did not switch to English")
        XCTAssertFalse(app.staticTexts["अध्याय"].exists)

        app.buttons["tocLanguageToggle"].tap()
        XCTAssertTrue(app.staticTexts["अध्याय"].waitForExistence(timeout: 3), "did not switch back")
    }

    /// The point of keeping it local: browsing the contents in English must not
    /// change what the reader is showing.
    func testContentsLanguageDoesNotChangeTheReader() {
        openContents()
        app.buttons["tocLanguageToggle"].tap()
        XCTAssertTrue(app.staticTexts["CHAPTERS"].waitForExistence(timeout: 3))

        app.buttons["tocClose"].tap()

        XCTAssertTrue(app.staticTexts["अनुवाद"].waitForExistence(timeout: 5),
                      "reader should still be in Sanskrit")
        XCTAssertFalse(app.staticTexts["TRANSLATION"].exists)
    }

    func testCloseButtonDismissesTheContents() {
        openContents()
        app.buttons["tocClose"].tap()
        XCTAssertFalse(app.buttons["tocLanguageToggle"].waitForExistence(timeout: 2),
                       "contents did not dismiss")
        XCTAssertTrue(app.staticTexts["verseReference"].exists)
    }
}

/// Reading position survives quitting the app.
final class ResumeUITests: XCTestCase {

    func testReopensOnTheLastVerseRead() {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash"]
        app.launch()

        let reference = app.staticTexts["verseReference"]
        XCTAssertTrue(reference.waitForExistence(timeout: 10))
        XCTAssertTrue(reference.label.contains("1.1"), "should start at the beginning")

        for _ in 0 ..< 3 { app.buttons["Next verse"].tap() }
        let moved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "1.4"), object: reference
        )
        XCTAssertEqual(XCTWaiter().wait(for: [moved], timeout: 5), .completed,
                       "did not reach 1.4, showing \(reference.label)")

        // Quit outright — not backgrounded — and come back without resetting.
        app.terminate()
        app.launchArguments.removeAll { $0 == "-resetSettings" }
        app.launch()

        XCTAssertTrue(reference.waitForExistence(timeout: 10))
        let resumed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "1.4"), object: reference
        )
        XCTAssertEqual(XCTWaiter().wait(for: [resumed], timeout: 5), .completed,
                       "did not resume at 1.4, showing \(reference.label)")
    }
}

/// Immersive reading: the verse gets the whole screen, and the controls come
/// back only when asked for.
final class ImmersiveUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
        app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-immersive"]
        app.launch()
        XCTAssertTrue(app.staticTexts["अनुवाद"].waitForExistence(timeout: 10),
                      "the reader never appeared")
    }

    private var chromeShowing: Bool { app.staticTexts["verseReference"].exists }

    /// Polls rather than sampling once. `exists` read the instant a launch or a
    /// swipe finishes catches the accessibility tree mid-settle, which showed up
    /// as this suite failing roughly one run in three and passing in isolation.
    private func expectChromeHidden(
        _ message: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.staticTexts["verseReference"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 3), .completed,
                       message, file: file, line: line)
    }

    func testChromeHidesWhileReading() {
        expectChromeHidden("controls should be hidden in immersive mode")
        XCTAssertTrue(app.staticTexts["अनुवाद"].exists, "the verse should still be there")
    }

    /// The point of the feature: turning pages must not keep flashing the
    /// controls back at the reader.
    func testPagingDoesNotBringTheChromeBack() {
        expectChromeHidden("controls should start hidden")

        app.swipeLeft()
        expectChromeHidden("a swipe brought the controls back")

        app.swipeRight()
        expectChromeHidden("a swipe back brought the controls back")
    }

    func testTappingTheBottomEdgeBringsThemBack() {
        expectChromeHidden("controls should start hidden")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)).tap()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 3),
                      "tapping the bottom edge did not reveal the controls")
    }

    func testTappingTheTopEdgeBringsThemBack() {
        expectChromeHidden("controls should start hidden")

        // Just below the status bar: taps inside it never reach the app.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09)).tap()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 3),
                      "tapping the top edge did not reveal the controls")
    }

    /// The edge strips are small targets. A double tap anywhere on the page is
    /// the forgiving way back to the controls.
    func testDoubleTappingThePageBringsThemBack() {
        expectChromeHidden("controls should start hidden")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleTap()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 3),
                      "a double tap on the page did not reveal the controls")
    }

    /// A single tap is how you stop a fling. It must not summon the toolbar,
    /// or the chrome would flash back on every arrested scroll.
    func testASingleTapOnThePageDoesNothing() {
        expectChromeHidden("controls should start hidden")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(app.staticTexts["verseReference"].waitForExistence(timeout: 2),
                       "a single tap revealed the controls")
    }

    func testRevealedChromeHidesItselfAgain() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)).tap()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 3))

        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.staticTexts["verseReference"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed,
                       "the controls stayed up instead of hiding again")
    }
}
