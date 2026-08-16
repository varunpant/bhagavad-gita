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

    @Test func theLinkMatchesTheWebsitesUrlShape() throws {
        let verse = try verse(2, 47)
        #expect(verse.shareURL.absoluteString == "https://bhagwadgita.info/chapter-2/sutra-47/")
    }

    @Test func everyVerseProducesAValidLink() throws {
        let verses = try #require(try? ContentDatabase().allVerses())
        for verse in verses {
            let url = verse.shareURL
            #expect(url.scheme == "https")
            #expect(url.path.contains("chapter-\(verse.chapter)"))
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
        #expect(!text.contains("bhagwadgita.info"))
        #expect(text.contains("Bhagavad Gita 2.47"))
    }

    @MainActor
    @Test func theCardRendersInBothLanguages() throws {
        let verse = try verse(2, 47)
        #expect(ShareCard.render(verse: verse, language: .sanskrit) != nil)
        #expect(ShareCard.render(verse: verse, language: .english) != nil)
    }

    /// An unenriched verse has no translation. The card must still render,
    /// rather than producing nothing at all.
    @MainActor
    @Test func theCardRendersWithoutATranslation() throws {
        let verses = try #require(try? ContentDatabase().allVerses())
        guard let bare = verses.first(where: { $0.englishTranslation == nil }) else { return }
        #expect(ShareCard.render(verse: bare, language: .english) != nil)
    }
}

#if canImport(AppKit)
import AppKit
#endif

#if DEBUG
/// Writes a sample card into the test process's own temporary directory, which
/// the sandbox permits, and logs where it went. Not an assertion — it exists so
/// the card can be eyeballed after a design change.
struct ShareCardSampleTests {
    @MainActor
    @Test func writeSampleCards() throws {
        let verses = try #require(try? ContentDatabase().allVerses())
        let verse = try #require(verses.first { $0.chapter == 2 && $0.sutra == 47 })

        for language in [ReadingLanguage.sanskrit, .english] {
            let renderer = ImageRenderer(content: ShareCard(verse: verse, language: language))
            renderer.scale = 1
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { continue }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("card-\(language.rawValue).png")
            try png.write(to: url)
            print("CARD_WRITTEN \(url.path)")
        }
    }
}
#endif
