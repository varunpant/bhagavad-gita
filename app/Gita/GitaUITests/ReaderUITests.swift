//
//  ReaderUITests.swift
//  GitaUITests
//

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

    private var reference: String {
        let label = app.staticTexts["verseReference"]
        XCTAssertTrue(label.waitForExistence(timeout: 10), "reader never appeared")
        return label.label
    }

    func testOpensAtTheFirstVerse() {
        XCTAssertEqual(reference, "1.1")
    }

    func testNextButtonAdvancesOneVerse() {
        XCTAssertEqual(reference, "1.1")
        app.buttons["Next verse"].tap()
        XCTAssertEqual(reference, "1.2")
    }

    func testSwipeMovesForwardAndBack() {
        XCTAssertEqual(reference, "1.1")
        app.swipeLeft()
        XCTAssertEqual(reference, "1.2")
        app.swipeRight()
        XCTAssertEqual(reference, "1.1")
    }

    func testCannotGoBackFromTheFirstVerse() {
        XCTAssertFalse(app.buttons["Previous verse"].isEnabled)
    }
}
