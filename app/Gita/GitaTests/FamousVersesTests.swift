//
//  FamousVersesTests.swift
//  GitaTests
//

import Foundation
import Testing

@testable import Gita

/// `FamousVerses` is a hand-written list of chapter and verse numbers, and the
/// one way it can go wrong is silently: a number that matches no verse simply
/// never marks anything, and a chip that is missing a rule looks exactly like a
/// chip that was never meant to have one.
///
/// So the list is checked against the corpus rather than trusted. This is the
/// same bargain `WelcomeSampleTests` makes with the sample verse — a constant
/// about the text, pinned to the text.
@Suite("Famous verses")
struct FamousVersesTests {

    private func corpus() throws -> [Verse] {
        let library = try ContentDatabase()
        return try library.allVerses()
    }

    @Test("Every reference names a verse that exists")
    func everyReferenceResolves() throws {
        let verses = try corpus()
        let existing = Set(verses.map { FamousVerses.Reference($0.chapter, $0.sutra) })

        let missing = FamousVerses.all.subtracting(existing)
            .sorted { ($0.chapter, $0.sutra) < ($1.chapter, $1.sutra) }
            .map { "\($0.chapter).\($0.sutra)" }

        #expect(missing.isEmpty, "no such verse: \(missing.joined(separator: ", "))")
    }

    @Test("The marker stays rare enough to mean something")
    func theListIsNotTheWholeBook() throws {
        let verses = try corpus()
        // A marker on a tenth of the book still picks a verse out of a chapter
        // grid; a marker on a third of it is wallpaper. This is a design
        // constraint rather than an arithmetic one, which is why it is written
        // down where adding fifty more would trip it.
        #expect(FamousVerses.all.count < verses.count / 8)
    }

    @Test("Verse.isFamous agrees with the list")
    func versesKnowTheirOwnFame() throws {
        let verses = try corpus()
        let famous = verses.filter(\.isFamous)

        #expect(famous.count == FamousVerses.all.count)
        for verse in famous {
            #expect(FamousVerses.contains(chapter: verse.chapter, sutra: verse.sutra))
        }
    }

    @Test("The best known verse of all is on the list")
    func theObviousOnes() {
        #expect(FamousVerses.contains(chapter: 2, sutra: 47))
        #expect(FamousVerses.contains(chapter: 18, sutra: 66))
        #expect(!FamousVerses.contains(chapter: 2, sutra: 46))
    }
}
