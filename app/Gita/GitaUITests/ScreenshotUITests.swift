//
//  ScreenshotUITests.swift
//  GitaUITests
//

import Foundation
import XCTest

/// App Store capture. Not a test of anything — it drives the app to five screens
/// and writes what it sees to disk, and it drives a slower scripted tour that the
/// host records as the preview video.
///
/// Never run as part of the suite. `tools/make_appstore_media.py` runs it with
/// `-only-testing`, on a 6.9" iPhone, and turns what lands in
/// `app/design/appstore/raw/` into the framed panels beside it.
///
///     .venv/bin/python tools/make_appstore_media.py
///
/// Writing straight into the repository works because a simulator process is not
/// sandboxed against the host filesystem, and `#filePath` is resolved when this
/// file is compiled — so the test knows where it came from even though it is
/// running inside the simulator.
@MainActor
final class ScreenshotUITests: XCTestCase {

    /// `.../app/Gita/GitaUITests/ScreenshotUITests.swift` → `.../app/design/appstore/raw`
    private static let output: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // GitaUITests
        .deletingLastPathComponent()   // Gita
        .deletingLastPathComponent()   // app/Gita
        .appendingPathComponent("design/appstore/raw", isDirectory: true)

    override func setUp() async throws {
        continueAfterFailure = false
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
        try FileManager.default.createDirectory(
            at: Self.output, withIntermediateDirectories: true
        )
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash"] + arguments
        app.launch()
        return app
    }

    /// The whole screen at device resolution, so the panel compositor gets real
    /// 1290×2796 pixels rather than a window-sized crop.
    private func capture(_ name: String) throws {
        // A beat for the last animation to settle. Screenshots taken mid-spring
        // catch panels half-open, which is worse than the two seconds it costs.
        Thread.sleep(forTimeInterval: 1.2)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try png.write(to: Self.output.appendingPathComponent("\(name).png"))
    }

    private func openVerse(_ chapter: Int, _ verse: Int, in app: XCUIApplication) {
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.buttons["Contents"].waitForExistence(timeout: 5))
        app.buttons["Contents"].tap()

        let row = app.buttons["chapter-\(chapter)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let target = app.buttons["Verse \(chapter).\(verse)"]
        for _ in 0 ..< 8 where !target.isHittable { app.swipeUp() }
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.tap()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 5))
    }

    // MARK: - Stills

    /// 1 — the book as it opens: Devanagari, on the verse the whole Gita is
    /// quoted for.
    func test1Sanskrit() throws {
        let app = launch([])
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 15))
        openVerse(2, 47, in: app)
        try capture("1-sanskrit")
    }

    /// 2 — the same verse in English, which is the other half of the promise.
    func test2English() throws {
        let app = launch(["-startInEnglish"])
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 15))
        openVerse(2, 47, in: app)
        try capture("2-english")
    }

    /// 3 — search, with its results.
    ///
    /// The keyboard covers nearly half the screen while the field has focus, and
    /// a panel that is half keyboard says nothing about the app. The list is
    /// `.scrollDismissesKeyboard(.interactively)`, so dragging it down puts the
    /// keyboard away and leaves the results filling the screen.
    ///
    /// Shot in Dark on purpose. Search dims the page to 18% rather than covering
    /// it; in Light the reader's paragraphs show faintly through the results,
    /// which reads as depth on a moving screen and as a rendering fault in a
    /// still. The theme is forced rather than taken from the simulator's
    /// appearance — `theme` is the app's own setting, so `simctl ui appearance`
    /// does not reach it once a preference has been stored.
    func test3Search() throws {
        let app = launch(["-startInEnglish", "-forceTheme", "dark", "-openSearch"])
        let field = app.textFields["searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        // The newline is the search key. Nothing is bound to `onSubmit`, so all
        // it does is give up focus — which is exactly what is wanted: the query
        // stands, the results stay, the keyboard goes.
        field.typeText("karma\n")
        Thread.sleep(forTimeInterval: 2.5)      // let the query, the ranking and the rows land

        // Submitting does not give up focus — nothing is bound to `onSubmit`,
        // and SwiftUI keeps a field first responder through a return. What does
        // put the keyboard away is a drag on the results, which are
        // `.scrollDismissesKeyboard(.interactively)`. Drag the list itself, not
        // the screen: a full-screen swipe starts on the scrim, and a tap there
        // closes search altogether.
        app.scrollViews.firstMatch.swipeDown()
        try capture("3-search")
    }

    /// 4 — progress, seeded so the rings have something to say. Dark for the
    /// same reason as search: the panel slides the page aside rather than
    /// replacing it, and a strip of half-cut paragraph down the edge is the
    /// first thing the eye finds in a still.
    func test4Progress() throws {
        let app = launch(["-startInEnglish", "-forceTheme", "dark",
                          "-seedProgress", "-openProgressPanel"])
        XCTAssertTrue(app.buttons["progress-chapter-1"].waitForExistence(timeout: 15))
        try capture("4-progress")
    }

    /// The fifth panel is the share card, and it is *not* captured here: tapping
    /// through to it lands on the system share sheet, which is Apple's UI rather
    /// than the app's. The card itself is rendered straight from `ShareCard` by
    /// `GitaTests/ShareCardSampleTests`, which the media script runs on macOS.

    /// Not a panel — a design check. Opens a locked goal so the explanation
    /// sheet can be looked at after a change to it.
    func test8Goal() throws {
        let app = launch(["-startInEnglish", "-seedProgress", "-openProgressPanel"])
        let badge = app.buttons["badge-verses_250"]
        for _ in 0 ..< 16 where !badge.isHittable { app.swipeUp() }
        XCTAssertTrue(badge.waitForExistence(timeout: 10), "the goal was never reached")
        badge.tap()
        try capture("8-goal")
    }

    // MARK: - Tour, for the preview video

    /// A slow, legible walk through the app for the host to record. Everything
    /// here is paced for someone watching, not for a test — the pauses are the
    /// point, and the whole thing is about twenty seconds.
    ///
    /// The splash is deliberately *not* skipped: it is the brand ramp, and it is
    /// the right opening frame.
    func test9Tour() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-startInEnglish", "-seedProgress"]
        app.launch()

        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 1.5)

        // Read down one verse.
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1.2)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1.2)

        // Move through the book.
        app.buttons["Next verse"].tap()
        Thread.sleep(forTimeInterval: 1.5)

        // Jump to 2.47 by hand, so the contents panel is on screen on the way.
        openVerse(2, 47, in: app)
        Thread.sleep(forTimeInterval: 2.0)

        // Search.
        app.buttons["menuButton"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        app.buttons["Search"].tap()
        let field = app.textFields["searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("karma")
        Thread.sleep(forTimeInterval: 2.5)
        app.buttons["searchClose"].tap()
        Thread.sleep(forTimeInterval: 1.0)

        // And what has been read so far.
        app.buttons["menuButton"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        app.buttons["Progress"].tap()
        Thread.sleep(forTimeInterval: 3.0)
    }
}

/// Design checks that are not App Store panels: the same screen in both
/// scripts, so a change to the language rules can be looked at rather than
/// reasoned about. `make_appstore_media.py` does not run these.
@MainActor
final class LanguageCheckUITests: XCTestCase {

    private static let output: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("design/appstore/raw", isDirectory: true)

    override func setUp() async throws {
        continueAfterFailure = false
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
    }

    private func capture(_ name: String) throws {
        Thread.sleep(forTimeInterval: 1.0)
        try XCUIScreen.main.screenshot().pngRepresentation
            .write(to: Self.output.appendingPathComponent("\(name).png"))
    }

    private func openVerse(_ chapter: Int, _ verse: Int, in app: XCUIApplication) {
        app.buttons["menuButton"].tap()
        app.buttons["Contents"].tap()
        let row = app.buttons["chapter-\(chapter)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let target = app.buttons["Verse \(chapter).\(verse)"]
        for _ in 0 ..< 8 where !target.isHittable { app.swipeUp() }
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.tap()
    }

    private func contents(english: Bool, huge: Bool) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-seedProgress",
                                "-openContentsPanel"]
        if english { app.launchArguments += ["-startInEnglish"] }
        if huge {
            // The app pins Dynamic Type from its own text-size setting, so
            // `-UICTContentSizeCategoryOverride` has no effect here — this is
            // the only lever that moves the reading size.
            app.launchArguments += ["-forceTextSize", "extraLarge"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 15))
        return app
    }

    func testContentsInBothScripts() throws {
        _ = try contents(english: false, huge: false)
        try capture("check-toc-sa")
        _ = try contents(english: true, huge: false)
        try capture("check-toc-en")
    }

    /// The progress panel is the other half of the report: its chapter rows and
    /// its grid of goals both carry a name that changes length with the script.
    func testProgressInBothScripts() throws {
        for (english, name) in [(false, "check-progress-sa"), (true, "check-progress-en"),
                                (true, "check-progress-en-normal")] {
            let app = XCUIApplication()
            app.launchArguments += ["-resetSettings", "-skipSplash", "-seedProgress",
                                    "-openProgressPanel"]
            if !name.hasSuffix("normal") {
                app.launchArguments += ["-forceTextSize", "extraLarge"]
            }
            if english { app.launchArguments += ["-startInEnglish"] }
            app.launch()
            XCTAssertTrue(app.buttons["progress-chapter-1"].waitForExistence(timeout: 15))
            // One swipe: past the ring and the figures, to the chapter cards.
            // Three took the screen down into the badge grid, which is a
            // different thing wearing a similar heading.
            app.swipeUp()
            try capture(name)
        }
    }

    /// 1.26 in English, whose transliteration carries a 46-character sandhi
    /// compound — `ācāryānmātulānbhrātṝnputrānpautrānsakhīṃstathā`, one token
    /// with nowhere to break. Reported as the page overflowing to the right
    /// when the language is switched.
    func testALongTransliterationFitsThePage() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish",
                                "-forceTextSize", "extraLarge"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 15))

        app.buttons["menuButton"].tap()
        app.buttons["Contents"].tap()
        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 10))
        let verse = app.buttons["Verse 1.26"]
        for _ in 0 ..< 8 where !verse.isHittable { app.swipeUp() }
        verse.tap()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
        try capture("check-overflow-1.26-xl")
    }

    /// The word-by-word list in both scripts, which is where the page was
    /// reported to run off to the right when the language was switched.
    func testWordByWordFitsInBothScripts() throws {
        for (english, name) in [(true, "check-words-en"), (false, "check-words-sa")] {
            let app = XCUIApplication()
            app.launchArguments += ["-resetSettings", "-skipSplash"]
            if english { app.launchArguments += ["-startInEnglish"] }
            app.launch()
            XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 15))

            app.buttons["menuButton"].tap()
            app.buttons["Settings"].tap()
            let words = app.switches["toggleWordByWord"]
            for _ in 0 ..< 6 where !words.exists { app.swipeUp() }
            XCTAssertTrue(words.waitForExistence(timeout: 5))
            words.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            app.buttons["Close settings"].tap()
            app.buttons["Close menu"].firstMatch.tap()

            // 2.7 carries the longest compound in the list:
            // "kārpaṇya-doṣa-upahata-svabhāvaḥ".
            openVerse(2, 7, in: app)
            for _ in 0 ..< 4 { app.swipeUp() }
            try capture(name)

            // Checked by eye, not by assertion: XCUITest reports the
            // combined frame of the accessibility row, which stays inside the
            // window even when the text inside it is drawn off screen — so an
            // assertion on it passes with the bug present and proves nothing.
            // The two captures are the record.
        }
    }

    func testContentsAtAnAccessibilitySize() throws {
        _ = try contents(english: false, huge: true)
        try capture("check-toc-sa-large")
        _ = try contents(english: true, huge: true)
        try capture("check-toc-en-large")
    }
}

/// Does reading a verse actually mark it?
///
/// Written for a report that chapter 1's second and third verses would not mark
/// as read however often they were read. It walks the reader over 1.1, 1.2 and
/// 1.3 slowly enough for the dwell to fire on each, then reads the contents back.
@MainActor
final class ReadingMarksUITests: XCTestCase {

    func testWalkingTheFirstThreeVersesMarksAllThree() {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 15))

        // `ReadingPolicy.dwell` is three seconds; five is that plus room.
        Thread.sleep(forTimeInterval: 5)
        app.buttons["Next verse"].tap()
        Thread.sleep(forTimeInterval: 5)
        app.buttons["Next verse"].tap()
        Thread.sleep(forTimeInterval: 5)

        app.buttons["menuButton"].tap()
        app.buttons["Contents"].tap()
        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 10))
        // No tap: the contents open on the chapter the reader is in, so
        // chapter 1 is already expanded and tapping it would close it.

        for verse in 1 ... 3 {
            let chip = app.buttons["verse-1.\(verse)"]
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "no chip for 1.\(verse)")
            XCTAssertEqual(chip.value as? String, "Read",
                           "1.\(verse) was read but is not marked")
        }
    }

    /// Does a read survive the app being quit?
    ///
    /// `ReadingProgress.record` puts the verse in memory and schedules the
    /// database write on an unstructured task. If the app goes away before that
    /// task is given any time, the verse is read for the rest of the session and
    /// unread ever after — which is what "I read it but it is not marked" looks
    /// like from the outside.
    func testAReadSurvivesTheAppBeingQuit() {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 5)        // the three-second dwell, plus room
        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-skipSplash", "-openContentsPanel"]
        relaunched.launch()
        XCTAssertTrue(relaunched.buttons["chapter-1"].waitForExistence(timeout: 15))
        relaunched.buttons["chapter-1"].tap()

        let chip = relaunched.buttons["verse-1.1"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.value as? String, "Read",
                       "the read was lost when the app was quit")
    }

    /// The other way to mark: long-press a chip in the contents.
    func testMarkingAVerseByHandFromTheContents() {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish",
                                "-openContentsPanel"]
        app.launch()
        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 15))
        app.buttons["chapter-1"].tap()          // nothing is open on a cold launch

        let chip = app.buttons["verse-1.5"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "no chip for 1.5")
        XCTAssertEqual(chip.value as? String, "Not read")

        chip.press(forDuration: 1.2)
        let mark = app.buttons["Mark as read"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5), "no Mark as read in the menu")
        mark.tap()

        let marked = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Read"), object: chip
        )
        XCTAssertEqual(XCTWaiter().wait(for: [marked], timeout: 5), .completed,
                       "1.5 did not mark, value is \(String(describing: chip.value))")
    }
}

/// Where a short page sits on the screen.
///
/// With the translation turned off, a verse and its meaning are far shorter than
/// the screen. Both modes centre it now — immersive in the whole screen,
/// ordinary reading in the band between the header and the footer.
@MainActor
final class ImmersiveLayoutCheckUITests: XCTestCase {

    private static let output: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("design/appstore/raw", isDirectory: true)

    private func capture(_ name: String) throws {
        Thread.sleep(forTimeInterval: 1.2)
        try XCUIScreen.main.screenshot().pngRepresentation
            .write(to: Self.output.appendingPathComponent("\(name).png"))
    }

    /// Shloka and meaning only, which is the arrangement that showed the gap.
    private func shlokaAndMeaning(immersive: Bool, name: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish"]
        if immersive { app.launchArguments += ["-immersive"] }
        app.launch()

        // Immersive reading hides the chrome, including the rail button that
        // opens Settings. A tap on the page brings it back, which is how a
        // reader reaches it too.
        if immersive {
            Thread.sleep(forTimeInterval: 2)
            // The chrome comes back from a tap on the top or bottom 72pt strip,
            // not from a tap anywhere on the page — see `revealEdge`.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)).tap()
            Thread.sleep(forTimeInterval: 1)
        }
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 15))
        app.buttons["menuButton"].tap()
        app.buttons["Settings"].tap()
        let translation = app.switches["toggleTranslation"]
        XCTAssertTrue(translation.waitForExistence(timeout: 5))
        // The row is wide; the switch itself is at its trailing edge.
        translation.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["Close settings"].tap()
        app.buttons["Close menu"].firstMatch.tap()

        // Let the chrome fade back out before the shot, so what is captured is
        // the immersive page itself.
        if immersive { Thread.sleep(forTimeInterval: 4) }

        try capture(name)
    }

    func testAShortPageIsCentredInBothModes() throws {
        try shlokaAndMeaning(immersive: true, name: "check-centred-immersive")
        try shlokaAndMeaning(immersive: false, name: "check-centred-normal")
    }
}
