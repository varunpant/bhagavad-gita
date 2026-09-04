//
//  WelcomeSampleTests.swift
//  GitaTests
//

import Foundation
import Testing

@testable import Gita

/// `WelcomeSample` is verse 2.47, typed out by hand so the guide can draw a
/// card without opening the database.
///
/// Two files claimed this suite existed before it did — `WelcomeVignette`'s own
/// comment and `FamousVersesTests` — and in its absence the strings drifted:
/// the guide promised "You have a right to your action alone, never to its
/// fruits", which is a better line than the corpus has and is not in it. A
/// reader who followed the guide to 2.47 met different words, which is the one
/// thing an introduction to a book must not do.
///
/// So the constants are pinned to the corpus here. They are *excerpts* — a card
/// has no room for the whole of a translation — so each is checked as the
/// opening of what the database holds rather than the whole of it.
@Suite("Welcome sample")
struct WelcomeSampleTests {

    private func sample() throws -> Verse {
        let library = try ContentDatabase()
        let verse = try #require(
            try library.allVerses().first { $0.chapter == 2 && $0.sutra == 47 },
            "2.47 is missing from the corpus"
        )
        return verse
    }

    /// Punctuation is presentation: `build_db.py` strips every danda on the way
    /// in, and the app adds them back. Comparisons are made without them.
    private func bare(_ text: String) -> String {
        text.replacingOccurrences(of: "।", with: "")
            .replacingOccurrences(of: "॥", with: "")
            .replacingOccurrences(of: "|", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("The shloka is the verse's own first line")
    func theShlokaMatches() throws {
        let verse = try sample()
        let firstLine = try #require(verse.sanskrit.split(separator: "\n").first).description
        #expect(bare(WelcomeSample.shlokaSa) == bare(firstLine))

        let transliterated = try #require(verse.transliteration)
        let firstRoman = try #require(transliterated.split(separator: "\n").first).description
        #expect(bare(WelcomeSample.shlokaEn) == bare(firstRoman))
    }

    @Test("The translation is how the verse's own translation opens")
    func theTranslationMatches() throws {
        let verse = try sample()
        let english = try #require(verse.englishTranslation)
        let hindi = try #require(verse.hindiTranslation)
        #expect(english.hasPrefix(WelcomeSample.translationEn),
                "the guide promises words the verse does not use")
        #expect(hindi.hasPrefix(WelcomeSample.translationSa))
    }

    @Test("The meaning is how the verse's own meaning opens")
    func theMeaningMatches() throws {
        let verse = try sample()
        let english = try #require(verse.englishMeaning)
        let hindi = try #require(verse.hindiMeaning)
        #expect(english.hasPrefix(WelcomeSample.meaningEn))
        #expect(hindi.hasPrefix(WelcomeSample.meaningSa))
    }

    @Test("Every gloss is the verse's own, in the verse's own order")
    func theGlossesMatch() throws {
        let verse = try sample()

        let english = verse.words(for: .english)
        let hindi = verse.words(for: .sanskrit)
        #expect(english.count >= WelcomeSample.wordsEn.count)
        #expect(hindi.count >= WelcomeSample.wordsSa.count)

        for (index, gloss) in WelcomeSample.wordsEn.enumerated() {
            #expect(gloss.word == english[index].w, "word \(index + 1) drifted")
            #expect(gloss.gloss == english[index].m, "gloss for \(gloss.word) drifted")
        }
        for (index, gloss) in WelcomeSample.wordsSa.enumerated() {
            #expect(gloss.word == hindi[index].w, "word \(index + 1) drifted")
            #expect(gloss.gloss == hindi[index].m, "gloss for \(gloss.word) drifted")
        }
    }
}
