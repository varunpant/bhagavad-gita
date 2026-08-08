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
