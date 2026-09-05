//
//  DeepLinkTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

/// What a `gita://` URL resolves to.
///
/// The reason these are worth writing: a deep link that stops working fails
/// **silently**. There is no error path — a URL that does not parse simply does
/// nothing — so a widget that no longer opens its verse looks like a widget
/// that missed the tap, and a shared link that no longer works looks like the
/// recipient not having the app installed. Neither gets reported as what it is.
@Suite("Deep links")
struct DeepLinkTests {

    private func link(_ string: String) -> DeepLink? {
        URL(string: string).flatMap(DeepLink.init)
    }

    // MARK: - What the app sends

    @Test("A shared verse link opens that verse")
    func verseLinks() {
        #expect(link("gita://verse/2/47") == .verse(chapter: 2, sutra: 47))
        #expect(link("gita://verse/1/1") == .verse(chapter: 1, sutra: 1))
        #expect(link("gita://verse/18/78") == .verse(chapter: 18, sutra: 78))
    }

    @Test("The progress widget opens the progress panel")
    func progressLink() {
        #expect(link("gita://progress") == .progress)
    }

    /// The exact string `Verse.shareURL` builds, parsed back.
    ///
    /// The round trip is the point: these are two halves of the same feature
    /// written in different files, and nothing else makes them agree.
    @Test("Every verse's own share URL parses back to it", arguments: [
        (1, 1), (2, 47), (9, 22), (12, 13), (18, 66), (18, 78),
    ])
    func shareURLsRoundTrip(chapter: Int, sutra: Int) throws {
        let verse = try #require(
            try ContentDatabase().allVerses()
                .first { $0.chapter == chapter && $0.sutra == sutra }
        )
        #expect(DeepLink(verse.shareURL) == .verse(chapter: chapter, sutra: sutra))
    }

    // MARK: - What it must ignore

    /// Another app's URL, or a web link. Silence, not a crash and not a guess.
    @Test("A URL from anywhere else is ignored", arguments: [
        "https://bhagwadgita.info/chapter-2/sutra-47/",
        "http://verse/2/47",
        "geeta://verse/2/47",
        "gitaa://verse/2/47",
        "verse/2/47",
        "mailto:varun@varunpant.com",
    ])
    func foreignURLsAreIgnored(string: String) {
        #expect(link(string) == nil, "\(string) should not resolve")
    }

    /// A `gita://` URL the app would never build. Half a reference is not a
    /// reference, and guessing at the missing half would open the wrong verse.
    @Test("A malformed gita URL resolves to nothing", arguments: [
        "gita://verse",
        "gita://verse/2",
        "gita://verse/2/47/extra",
        "gita://verse/x/47",
        "gita://verse/2/y",
        "gita://verse//47",
        "gita://verse/0/47",
        "gita://verse/2/0",
        "gita://verse/-2/47",
        "gita://chapter/2",
        "gita://",
    ])
    func malformedLinksResolveToNothing(string: String) {
        #expect(link(string) == nil, "\(string) should not resolve")
    }

    /// A reference the URL is well-formed for but the book does not contain.
    ///
    /// Deliberately *not* rejected here: `DeepLink` answers what the URL says,
    /// and whether the Gita has a chapter 19 is the corpus's business. The
    /// reader looks it up and finds nothing, which is the same path a widget
    /// takes when its verse has been removed.
    @Test("An out-of-range reference still parses, and is the corpus's problem")
    func outOfRangeIsNotThisTypesJob() throws {
        #expect(link("gita://verse/19/1") == .verse(chapter: 19, sutra: 1))

        let library = try ContentDatabase()
        let exists = try library.allVerses().contains { $0.chapter == 19 }
        #expect(!exists, "the corpus grew a chapter 19 and this test is now wrong")
    }
}
