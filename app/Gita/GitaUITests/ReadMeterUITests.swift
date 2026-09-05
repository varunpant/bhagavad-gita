//
//  ReadMeterUITests.swift
//  GitaUITests
//

import XCTest

/// The mark that says a verse counted.
///
/// `ReadingPolicy` has always decided this — three seconds on screen,
/// uncovered, in the foreground — and until now it decided it invisibly: the
/// only evidence was a filled circle in the contents, found later, looking
/// arbitrary. The meter beside the bookmark shows the three seconds passing and
/// leaves a tick behind.
///
/// Worth a UI test rather than a unit test because the thing being checked is
/// whether the mark is *on the page*. `ReadingPolicyTests` already pins when a
/// verse counts; nothing pinned that the reader is told.
@MainActor
final class ReadMeterUITests: XCTestCase {

    override func setUp() async throws {
        continueAfterFailure = false
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish"] + arguments
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 20),
                      "the reader never appeared")
        return app
    }

    /// A verse read on some earlier day still says so when it is opened.
    ///
    /// `-seedProgress` marks the whole of chapter 1, and the reader opens on
    /// 1.1, so the tick has to be there before anything is waited for.
    func testAnAlreadyReadVerseShowsTheTick() {
        let app = launch(["-seedProgress"])

        XCTAssertTrue(app.descendants(matching: .any)["readTick"].waitForExistence(timeout: 5),
                      "an already-read verse showed no tick")
    }

    /// An unread verse earns one, and only after the dwell.
    ///
    /// Both halves matter. If the tick were there at once the meter would be
    /// decoration rather than a report, and if it never arrived the reader
    /// would be told nothing at all.
    func testAnUnreadVerseEarnsTheTick() {
        let app = launch([])
        let tick = app.descendants(matching: .any)["readTick"]

        XCTAssertFalse(tick.exists, "an unread verse already had a tick")

        // The dwell is three seconds; five is that plus room for a slow launch.
        XCTAssertTrue(tick.waitForExistence(timeout: 5),
                      "the verse was on screen for the dwell and never counted")
    }

    /// Browsing the contents is not reading, so nothing is earned behind it.
    ///
    /// This is the rule `ReadingPolicy.shouldCount` states as `!isCovered`, and
    /// it is the one most easily lost: the dwell is a sleeping task, and a task
    /// that is not cancelled when the rail opens will happily fire behind it.
    func testAVerseCoveredByTheRailDoesNotCount() {
        let app = launch([])

        // Open the rail immediately — well inside the three seconds.
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.buttons["Contents"].waitForExistence(timeout: 5))

        // Long enough that an uncancelled dwell would have fired twice over.
        Thread.sleep(forTimeInterval: 6)

        app.buttons["Close menu"].firstMatch.tap()
        XCTAssertFalse(app.descendants(matching: .any)["readTick"].waitForExistence(timeout: 2),
                       "a verse counted while the rail was over it")
    }
}
