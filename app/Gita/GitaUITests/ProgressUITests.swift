//
//  ProgressUITests.swift
//  GitaUITests
//

import Foundation
import XCTest

/// The progress panel: reached from the rail, and a way back into the book.
final class ProgressUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
        app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish", "-seedProgress"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
    }

    private func openProgress() {
        app.buttons["menuButton"].tap()
        app.buttons["Progress"].tap()
    }

    func testProgressOpensFromTheRailAndKeepsIt() {
        openProgress()
        XCTAssertTrue(app.buttons["progress-chapter-1"].waitForExistence(timeout: 5),
                      "progress did not open")
        // The rail stays put — its icon becomes the close control, as with the
        // other panels.
        XCTAssertTrue(app.buttons["Close progress"].exists, "the rail closed instead of staying")
    }

    func testEveryChapterIsListed() {
        openProgress()
        XCTAssertTrue(app.buttons["progress-chapter-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["progress-chapter-18"].exists)
    }

    /// Progress is a way back into the book, not just a statistic.
    func testChoosingAChapterMovesTheReaderAndClosesTheRail() {
        openProgress()
        XCTAssertTrue(app.buttons["progress-chapter-2"].waitForExistence(timeout: 5))
        app.buttons["progress-chapter-2"].tap()

        let reference = app.staticTexts["verseReference"]
        XCTAssertTrue(reference.waitForExistence(timeout: 5))
        let matched = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "2.1"), object: reference
        )
        XCTAssertEqual(XCTWaiter().wait(for: [matched], timeout: 5), .completed,
                       "reader did not move to 2.1, showing \(reference.label)")
        XCTAssertFalse(app.buttons["Close progress"].exists, "the panel stayed open")
    }
}
