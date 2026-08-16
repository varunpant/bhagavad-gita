//
//  ShareUITests.swift
//  GitaUITests
//

import Foundation
import XCTest

/// The share control under each verse.
final class ShareUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
        app = XCUIApplication()
        app.launchArguments += ["-resetSettings", "-skipSplash", "-startInEnglish"]
        app.launch()
        XCTAssertTrue(app.staticTexts["verseReference"].waitForExistence(timeout: 10))
    }

    /// The pager keeps neighbouring verses alive, so several share buttons
    /// exist at once and only one of them is on screen.
    private func visibleShareButton() -> XCUIElement? {
        app.buttons.matching(identifier: "shareButton")
            .allElementsBoundByIndex.first { $0.isHittable }
    }

    private func openShare() {
        for _ in 0 ..< 14 where visibleShareButton() == nil { app.swipeUp() }
        guard let button = visibleShareButton() else {
            return XCTFail("share button never came into view")
        }
        button.tap()
    }

    func testTheShareButtonOffersBothALinkAndAnImage() {
        openShare()
        XCTAssertTrue(app.buttons["shareLink"].firstMatch.waitForExistence(timeout: 5),
                      "no link option")
        XCTAssertTrue(app.buttons["shareImage"].firstMatch.exists, "no image option")
    }

    /// Turning the setting off takes the control away entirely.
    func testTheBarCanBeTurnedOff() {
        app.buttons["menuButton"].tap()
        app.buttons["Settings"].tap()

        let toggle = app.switches["toggleShareBar"]
        for _ in 0 ..< 6 where !toggle.exists { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()

        app.buttons["Close settings"].tap()
        app.buttons["Close menu"].firstMatch.tap()

        for _ in 0 ..< 14 { app.swipeUp() }
        XCTAssertFalse(app.buttons["shareButton"].firstMatch.exists,
                       "the share bar survived being turned off")
    }
}
