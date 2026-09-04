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

    /// A slow, legible walk through the app for the host to record.
    ///
    /// Everything here is paced for someone watching, not for a test — the
    /// pauses are the point. The shot list it follows is
    /// `app/design/appstore/video/preview-script.md`; change that first, then
    /// change this to match.
    ///
    /// The splash is deliberately *not* skipped: it is the brand ramp, and it is
    /// the right opening frame.
    ///
    /// Beside the recording it writes `tour-timeline.json`, which is how the
    /// captions know when to appear. Guessing at the timings from the sleeps
    /// below does not work — a beat costs whatever the simulator's springs,
    /// queries and layout passes cost on the day, and by the last beat the
    /// error is seconds. The run measures itself instead, and
    /// `make_appstore_media.py` maps those offsets onto the movie.
    func test9Tour() throws {
        let app = XCUIApplication()
        // Devanagari, not English: beat 0 opens on the original script, and
        // beat 2 is the switch. `-seedProgress` fills the rings that beat 3 and
        // beat 6 exist to show.
        app.launchArguments += ["-resetSettings", "-seedProgress", "-showWordByWord"]
        app.launch()

        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 20))
        // Everything after this is measured from here — the moment the app has
        // the screen, which is also the frame the transcode trims to.
        let tour = Timeline()

        // 0 — the book, open at its first verse, in Devanagari.
        tour.beat("opening")
        tour.show()
        Thread.sleep(forTimeInterval: 1.9)

        // 1 — down the page: translation, meaning, then every word explained.
        //
        // No tap through to the next verse any more. Every XCUITest action costs
        // a second or more of accessibility work, and the take has to fit inside
        // thirty seconds — so the actions that survive are the ones that put a
        // *feature* on screen. Paging between verses is shown by the contents
        // and by search, twice over.
        tour.beat("verse")
        app.swipeUp()
        tour.show()
        Thread.sleep(forTimeInterval: 2.0)

        // 2 — the script switch, which lives on the rail because it changes the
        // whole app rather than the page.
        //
        // The rail stays open from here until search sends the reader to a
        // verse. Closing it and reopening it for the next panel cost two taps
        // and nearly three seconds, and the open rail is worth seeing: it is
        // where the switch and the panels are.
        tour.beat("language")
        app.buttons["menuButton"].tap()
        let toggle = app.buttons["languageToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        // Wait for the switch to actually land before the caption claims it.
        // Tapped 0.4s after the rail was asked to open, the tap fell on a rail
        // still sliding and did nothing at all — and "Read in Sanskrit or in
        // English" then sat over a page of unchanged Devanagari. The reference
        // in the header is the proof: it is the one thing on the page that is
        // written in whichever language is on.
        XCTAssertTrue(app.staticTexts["Chapter 1 · Verse 1"].waitForExistence(timeout: 5),
                      "the language did not switch")
        tour.show()
        Thread.sleep(forTimeInterval: 2.0)

        // 3 — the contents, held long enough for the gold rings to register.
        //
        // It does not tap through to a verse: a ringed verse is a dozen rows
        // down a list of seven hundred, and every swipe towards one costs a
        // fresh accessibility snapshot of the whole panel. Beat 4 arrives at a
        // verse by searching for it instead, which is a better thing to watch.
        tour.beat("contents")
        app.buttons["Contents"].tap()
        // No tap on a chapter row: the panel opens on the chapter being read,
        // already expanded, already showing its grid of verse numbers with the
        // gold rings in it. The tap that used to be here expanded a second
        // chapter and cost a second and a half to show the same thing.
        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 5))
        tour.show()
        // The ringed verses are what this pause is for. Nothing moves; the eye
        // is doing the work.
        Thread.sleep(forTimeInterval: 2.0)

        // 4 — search, from the rail, which is still open beside the contents.
        tour.beat("search")
        app.buttons["Search"].tap()
        let field = app.textFields["searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("karma")
        Thread.sleep(forTimeInterval: 0.9)
        // Drag the results *down* to put the keyboard away: the list is
        // `.scrollDismissesKeyboard(.interactively)`, which follows a downward
        // drag. Dragging up scrolls the results and leaves the keyboard sitting
        // over the bottom third — which is exactly where the caption goes.
        let results = app.scrollViews.containing(.button, identifier: "searchResult").firstMatch
        results.swipeDown()
        tour.show()
        Thread.sleep(forTimeInterval: 1.5)
        // Into the first result. Choosing a row is also what puts the rail, the
        // panel and the search away in one move — `Drawer.requestVerse` clears
        // all three, which is why the reader is live again for beat 5. Tapping
        // `searchClose` instead leaves the rail open behind it, and the reader
        // disabled underneath, which is how the first take of this tour failed.
        app.buttons.matching(identifier: "searchResult").element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 1.1)

        // 5 — keep it, or send it. The share popup is where this stops: one tap
        // further is the system share sheet, which is Apple's UI and not ours.
        tour.beat("keep")
        app.buttons["bookmarkButton"].tap()
        tour.show()
        Thread.sleep(forTimeInterval: 0.7)
        // The share icon is under the verse, so on a long one it starts below
        // the fold — and the only `shareButton` in the tree is then the
        // neighbouring page's, off at x = -170 and disabled. Scroll to it.
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.6)
        if let share = onscreen("shareButton", in: app) {
            share.tap()
            Thread.sleep(forTimeInterval: 1.0)
            // Dismiss the popover by tapping outside it rather than by pressing
            // either row — both rows are `ShareLink`s.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
            Thread.sleep(forTimeInterval: 0.3)
        } else {
            // The bookmark is half the beat and it has already happened. A take
            // that films six beats is worth having; one that throws here is not.
            XCTContext.runActivity(named: "no share icon on this verse") { _ in }
            Thread.sleep(forTimeInterval: 1.0)
        }

        // 6 — what the reading has added up to.
        tour.beat("progress")
        app.buttons["menuButton"].tap()
        Thread.sleep(forTimeInterval: 0.4)
        app.buttons["Progress"].tap()
        tour.show()
        Thread.sleep(forTimeInterval: 1.2)
        // Down past the ring and the figures to the chapter cards and the goals.
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1.3)

        tour.end()
        try tour.write(to: Self.output.appendingPathComponent("tour-timeline.json"))
    }

    /// The one on the page in front of the reader.
    ///
    /// The reader is a horizontal pager, so the verse to the left and the verse
    /// to the right are built and present in the accessibility tree with the
    /// same identifiers as the one on screen. `app.buttons["shareButton"]` took
    /// the first of the three, which sat at x = -170 and was disabled, and the
    /// take failed there twice.
    /// Waits for one, because a page that has just been paged to is laid out a
    /// beat after it is asked for.
    ///
    /// Judged on the **frame**, not on `isHittable` or `isEnabled`. Both are
    /// true for the neighbouring page's copy sitting at x = -170 — XCUITest
    /// reasons that it could scroll it into view, and then the scroll it tries
    /// fails and takes the take with it. A control the camera cannot see is not
    /// the control this wants, whatever the snapshot says about it.
    private func onscreen(_ identifier: String, in app: XCUIApplication,
                          timeout: TimeInterval = 4) -> XCUIElement? {
        let screen = app.windows.firstMatch.frame
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let candidates = app.buttons.matching(identifier: identifier)
            for index in 0 ..< candidates.count {
                let candidate = candidates.element(boundBy: index)
                guard candidate.exists, candidate.isEnabled else { continue }
                if screen.contains(candidate.frame), candidate.isHittable {
                    return candidate
                }
            }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        return nil
    }

}

/// When each beat of the tour began, in seconds from the app taking the screen.
///
/// Only the timings live here. The caption copy is in
/// `tools/make_appstore_media.py`, beside the captions for the still panels, so
/// the marketing words can be changed without rebuilding a test target — this
/// side records `contents`, that side decides it says "Every chapter, every
/// verse".
private final class Timeline {
    private let started = Date()
    private var beats: [(name: String, at: TimeInterval, show: TimeInterval)] = []

    func beat(_ name: String) {
        let now = Date().timeIntervalSince(started)
        beats.append((name, now, now))
    }

    /// The moment the beat's payoff is actually on screen — after the taps that
    /// set it up, and after the rail has finished sliding.
    ///
    /// Without this the caption arrived with the beat, which meant "Read in
    /// Sanskrit or in English" sat over a rail opening and "the famous ones
    /// ringed in gold" over a page of prose. A caption describing a screen that
    /// is not up yet is worse than no caption: it reads as a claim the app did
    /// not keep.
    func show() {
        guard let last = beats.indices.last else { return }
        beats[last].show = Date().timeIntervalSince(started)
    }

    /// The end of the last beat, so a caption knows when to leave.
    func end() {
        let now = Date().timeIntervalSince(started)
        beats.append(("end", now, now))
    }

    func write(to url: URL) throws {
        let entries = beats.map {
            ["name": $0.name,
             "at": String(format: "%.2f", $0.at),
             "show": String(format: "%.2f", $0.show)]
        }
        let data = try JSONSerialization.data(
            withJSONObject: entries, options: [.prettyPrinted]
        )
        try data.write(to: url)
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

    /// Every page of the welcome, which is also the guide.
    func testTheWelcomeSlider() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-showWelcome"]
        app.launch()

        let advance = app.buttons["welcomeAdvance"]
        XCTAssertTrue(advance.waitForExistence(timeout: 15), "the welcome did not open")
        try capture("check-welcome-1")

        // Choose English on the first page, so the rest is in English — the
        // whole point of asking there.
        app.buttons["welcomeLanguage-english"].tap()
        try capture("check-welcome-1-english")

        // Nine pages — keep in step with WelcomePage.all.count.
        for page in 2 ... 9 {
            advance.tap()
            try capture("check-welcome-\(page)")
        }

        // The last page begins the reading, and the welcome does not come back.
        advance.tap()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
        XCTAssertFalse(advance.exists, "the welcome stayed up")
    }

    /// A kept verse: nothing on the shloka, the header's bookmark filled with
    /// the brand ramp.
    func testAKeptVerseIsMarkedOnlyOnTheButton() throws {
        let app = XCUIApplication()
        // Seeded, so 1.1 is already read: otherwise the dwell earns "First
        // Step" while the shot is being taken and the confetti covers the very
        // button this is about.
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish",
                                "-seedProgress"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 15))
        try capture("check-bookmark-before")

        app.buttons["bookmarkButton"].tap()
        try capture("check-bookmark-after")
    }

    /// The moment a goal is earned.
    ///
    /// Reading the very first verse earns "First Step", so the dwell alone
    /// raises it. The confetti itself cannot be checked from here — a
    /// screenshot takes about two seconds to come back and the fall lasts
    /// about two, so stills step straight over it. It was watched by recording
    /// the screen with `simctl io recordVideo` while this ran. What is asserted
    /// is the part that stills can see: that the goal is announced at all.
    func testAGoalEarnedRainsConfetti() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 15))

        // `ReadingPolicy.dwell` is three seconds; the badge lands just after.
        let toast = app.staticTexts["First Step"]
        XCTAssertTrue(toast.waitForExistence(timeout: 10), "no goal was announced")
        try capture("check-goal-earned")
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
