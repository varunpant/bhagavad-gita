//
//  WelcomeArtUITests.swift
//  GitaUITests
//

import Foundation
import XCTest

/// Shoots the screenshots the welcome slider shows.
///
/// Not a test — a capture run, like `ScreenshotUITests`. It drives the app to
/// each screen the welcome talks about and writes the shot into
/// `app/design/media/welcome/<script>/`, where `tools/make_welcome_art.py`
/// trims it, scales it and packs it into the asset catalogue.
///
/// Both scripts, because the welcome shows the app in the language the reader
/// has just chosen, and an English screenshot under a Devanagari heading is the
/// exact fault the language rules exist to prevent.
///
///     xcodebuild … -only-testing:GitaUITests/WelcomeArtUITests test
///     .venv/bin/python tools/make_welcome_art.py
@MainActor
final class WelcomeArtUITests: XCTestCase {

    private static let output: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("design/media/welcome", isDirectory: true)

    private var script = "en"

    override func setUp() async throws {
        continueAfterFailure = false
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
    }

    private func capture(_ name: String) throws {
        let folder = Self.output.appendingPathComponent(script, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Thread.sleep(forTimeInterval: 1.2)
        try XCUIScreen.main.screenshot().pngRepresentation
            .write(to: folder.appendingPathComponent("\(name).png"))
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-seedProgress"] + arguments
        if script == "en" { app.launchArguments += ["-startInEnglish"] }
        app.launch()
        return app
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

    func testShootEnglish() throws {
        script = "en"
        try shootAll()
    }

    func testShootDevanagari() throws {
        script = "sa"
        try shootAll()
    }

    private func shootAll() throws {
        // The book itself.
        var app = launch([])
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 15))
        openVerse(2, 47, in: app)
        try capture("scripture")

        // Bookmarking, caught with the bookmark on.
        app.buttons["bookmarkButton"].tap()
        try capture("bookmark")

        // Where the verses are.
        app = launch(["-openMenu", "-openContentsPanel"])
        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 15))
        app.buttons["chapter-2"].tap()
        try capture("contents")

        // How it looks.
        app = launch(["-openMenu", "-openSettingsPanel"])
        XCTAssertTrue(app.switches["toggleTranslation"].waitForExistence(timeout: 15))
        try capture("appearance")

        // Search, with results and no keyboard.
        app = launch(["-openSearch"])
        let field = app.textFields["searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("karma\n")
        Thread.sleep(forTimeInterval: 2)
        app.scrollViews.firstMatch.swipeDown()
        try capture("search")

        // How far the reader has got.
        app = launch(["-openMenu", "-openProgressPanel"])
        XCTAssertTrue(app.buttons["progress-chapter-1"].waitForExistence(timeout: 15))
        try capture("progress")
    }
}
