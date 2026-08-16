//
//  SharingTests.swift
//  GitaTests
//

import Foundation
import SwiftUI
import Testing
@testable import Gita

/// What gets sent to someone else. The link shape must match the website's,
/// and the card must actually render — a nil render hides the image button
/// with no error anywhere.
struct SharingTests {

    private func verse(_ chapter: Int, _ sutra: Int) throws -> Verse {
        let verses = try #require(try? ContentDatabase().allVerses())
        return try #require(verses.first { $0.chapter == chapter && $0.sutra == sutra })
    }

    /// The same scheme the widgets deep-link with, so a shared verse opens
    /// straight to it. ReaderView's onOpenURL parses exactly this shape.
    @Test func theLinkIsTheAppsOwnDeepLink() throws {
        let verse = try verse(2, 47)
        #expect(verse.shareURL.absoluteString == "gita://verse/2/47")
    }

    @Test func everyVerseProducesALinkTheAppCanOpen() throws {
        let verses = try #require(try? ContentDatabase().allVerses())
        for verse in verses {
            let url = verse.shareURL
            #expect(url.scheme == "gita")
            #expect(url.host == "verse")
            // What onOpenURL splits on.
            let parts = url.pathComponents.filter { $0 != "/" }
            #expect(parts == [String(verse.chapter), String(verse.sutra)])
        }
    }

    @Test func theTitleFollowsTheLanguage() throws {
        let verse = try verse(2, 47)
        #expect(verse.shareTitle(for: .english) == "Bhagavad Gita 2.47")
        #expect(verse.shareTitle(for: .sanskrit).contains("२.४७"))
    }

    /// The URL rides on ShareLink as the item; repeating it in the message puts
    /// it twice into anything that pastes both.
    @Test func theShareTextDoesNotRepeatTheLink() throws {
        let text = try verse(2, 47).shareText(for: .english)
        #expect(!text.contains("gita://"))
        #expect(text.contains("Bhagavad Gita 2.47"))
    }

    @MainActor
    @Test func theCardRendersInBothLanguages() throws {
        let verse = try verse(2, 47)
        #expect(ShareCard.png(verse: verse, language: .sanskrit) != nil)
        #expect(ShareCard.png(verse: verse, language: .english) != nil)
    }

    /// Real PNG bytes, not an empty file — the exporter hands these straight to
    /// the share sheet, and a zero-byte attachment fails silently there.
    @MainActor
    @Test func theCardIsARealPng() throws {
        let data = try #require(ShareCard.png(verse: try verse(2, 47), language: .sanskrit))
        #expect(data.count > 10_000)
        #expect(Array(data.prefix(4)) == [0x89, 0x50, 0x4E, 0x47])   // PNG magic
    }

    /// An unenriched verse has no translation. The card must still render,
    /// rather than producing nothing at all.
    @MainActor
    @Test func theCardRendersWithoutATranslation() throws {
        let verses = try #require(try? ContentDatabase().allVerses())
        guard let bare = verses.first(where: { $0.englishTranslation == nil }) else { return }
        #expect(ShareCard.png(verse: bare, language: .english) != nil)
    }
}

#if canImport(AppKit)
import AppKit
#endif

#if DEBUG && os(macOS)
/// Writes a sample card into the test process's own temporary directory, which
/// the sandbox permits, and logs where it went. Not an assertion — it exists so
/// the card can be eyeballed after a design change.
///
/// macOS only: it goes through `NSBitmapImageRep` to get a PNG, which does not
/// exist on iOS, and building the iOS test bundle failed on it.
struct ShareCardSampleTests {
    @MainActor
    @Test func writeSampleCards() throws {
        let verses = try #require(try? ContentDatabase().allVerses())
        let verse = try #require(verses.first { $0.chapter == 2 && $0.sutra == 47 })

        for language in [ReadingLanguage.sanskrit, .english] {
            guard let png = ShareCard.png(verse: verse, language: language) else { continue }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("card-\(language.rawValue).png")
            try png.write(to: url)
            print("CARD_WRITTEN \(url.path)")
        }
    }
}
#endif
