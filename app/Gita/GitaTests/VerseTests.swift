//
//  VerseTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

@Suite("Verse lines and punctuation")
struct VerseLineTests {

    private let opening = Verse(
        id: 1, chapter: 1, sutra: 1,
        sanskrit: "धृतराष्ट्र उवाच\nधर्मक्षेत्रे कुरुक्षेत्रे समवेता युयुत्सवः\nमामकाः पाण्डवाश्चैव किमकुर्वत सञ्जय",
        transliteration: "dhṛtarāṣṭra uvāca\ndharmakṣetre kurukṣetre samavetā yuyutsavaḥ\nmāmakāḥ pāṇḍavāścaiva kimakurvata sañjaya"
    )

    @Test("Stored text is split on newlines alone")
    func linesAreNewlineSeparated() {
        #expect(opening.lines == [
            "धृतराष्ट्र उवाच",
            "धर्मक्षेत्रे कुरुक्षेत्रे समवेता युयुत्सवः",
            "मामकाः पाण्डवाश्चैव किमकुर्वत सञ्जय",
        ])
    }

    @Test("Dandas are punctuation, added when drawing, never stored")
    func dandaIsAddedAtRender() {
        #expect(opening.sanskrit.contains("।") == false)
        #expect(opening.displayLines(for: .sanskrit) == [
            "धृतराष्ट्र उवाच",                                    // speaker: no danda
            "धर्मक्षेत्रे कुरुक्षेत्रे समवेता युयुत्सवः।",              // single danda
            "मामकाः पाण्डवाश्चैव किमकुर्वत सञ्जय॥",               // double closes the verse
        ])
    }

    @Test("The same punctuation is applied to the transliteration")
    func dandaAppliesToEnglishToo() {
        #expect(opening.displayLines(for: .english) == [
            "dhṛtarāṣṭra uvāca",
            "dharmakṣetre kurukṣetre samavetā yuyutsavaḥ।",
            "māmakāḥ pāṇḍavāścaiva kimakurvata sañjaya॥",
        ])
    }

    @Test("A verse with no speaker gets a danda on every line")
    func noSpeakerLine() {
        let verse = Verse(
            id: 60, chapter: 2, sutra: 47,
            sanskrit: "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन\nमा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि"
        )
        #expect(verse.displayLines(for: .sanskrit) == [
            "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।",
            "मा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि॥",
        ])
    }

    @Test("Speaker attributions are recognised in both scripts",
          arguments: ["धृतराष्ट्र उवाच", "सञ्जय उवाच", "dhṛtarāṣṭra uvāca", "arjuna uvāca"])
    func speakerDetection(line: String) {
        #expect(Verse.isSpeaker(line))
    }

    @Test("Ordinary verse lines are not mistaken for speakers")
    func nonSpeaker() {
        #expect(Verse.isSpeaker("मामकाः पाण्डवाश्चैव किमकुर्वत सञ्जय") == false)
    }

    @Test("Reference is the traditional chapter.verse form")
    func reference() {
        #expect(Verse(id: 1, chapter: 2, sutra: 47, sanskrit: "x").reference == "2.47")
    }
}

@Suite("Stored corpus shape")
struct CorpusShapeTests {

    @Test("No verse stores a danda or a verse-number marker")
    func punctuationIsStripped() throws {
        for verse in try ContentDatabase().allVerses() {
            #expect(verse.sanskrit.contains("।") == false, "danda left in \(verse.reference)")
            #expect(verse.sanskrit.contains("॥") == false, "double danda left in \(verse.reference)")
        }
    }

    @Test("Every verse is two or three lines")
    func lineCounts() throws {
        for verse in try ContentDatabase().allVerses() {
            #expect((2 ... 3).contains(verse.lines.count), "\(verse.reference) has \(verse.lines.count) lines")
        }
    }

    /// All four attribution forms must be split onto their own line — including
    /// श्रीभगवानुवाच, where sandhi leaves a combining ु rather than उ.
    @Test("Every speaker attribution stands alone on the first line")
    func speakerOnItsOwnLine() throws {
        var attributions = 0
        for verse in try ContentDatabase().allVerses() {
            if Verse.isSpeaker(verse.lines[0]) {
                attributions += 1
                #expect(verse.lines[0].count < 20, "\(verse.reference): verse text ran into the attribution")
            }
            // "उवाच" also occurs mid-verse as an ordinary verb — "तमुवाच" in
            // 2.10, "वाक्यमुवाच" in 2.1 — so its presence there is not a defect.
            // What matters is that no attribution opens a verse un-split.
        }
        #expect(attributions == 60, "expected 60 spoken verses, found \(attributions)")
    }

    @Test("The transliteration lays out on the same lines as the Devanagari")
    func transliterationMirrorsTheShloka() throws {
        for verse in try ContentDatabase().allVerses() where verse.isEnriched {
            #expect(Verse.lines(of: verse.scripture(for: .english)).count == verse.lines.count,
                    "\(verse.reference): transliteration line count differs")
        }
    }
}

@Suite("Bundled content database")
struct ContentDatabaseTests {

    @Test("Ships every verse, in reading order, with no gaps")
    func corpusIsComplete() throws {
        let verses = try ContentDatabase().allVerses()

        #expect(verses.count == 701)
        #expect(Set(verses.map(\.chapter)) == Set(1 ... 18))
        #expect(verses.allSatisfy { !$0.sanskrit.isEmpty })

        // Ordered by chapter, then verse.
        let keys = verses.map { [$0.chapter, $0.sutra] }
        #expect(keys == keys.sorted { $0.lexicographicallyPrecedes($1) })

        // Every chapter starts at verse 1 and runs unbroken.
        for chapter in 1 ... 18 {
            let sutras = verses.filter { $0.chapter == chapter }.map(\.sutra)
            #expect(sutras == Array(1 ... sutras.count), "chapter \(chapter) has a gap")
        }
    }

    @Test("Content version is stamped by the build script")
    func versionStamp() throws {
        #expect(try ContentDatabase().contentVersion() == "1")
    }
}

@Suite("Word-by-word glosses")
struct WordMeaningTests {

    /// The reason `WordMeaning` is not `Identifiable`: verses repeat words, so
    /// the word cannot be a list identity. 1.18 closes on "पृथक् पृथक्", and
    /// "च" appears three times in several verses of chapter 1.
    @Test("Repeated words are all preserved, not collapsed")
    func repeatedWordsSurvive() throws {
        let verses = try ContentDatabase().allVerses()

        guard let verse = verses.first(where: { $0.chapter == 1 && $0.sutra == 18 }),
              verse.isEnriched else {
            return  // not enriched yet; nothing to assert
        }

        let hindi = verse.words(for: .sanskrit)
        #expect(hindi.count == verse.words(for: .english).count)
        #expect(Set(hindi.map(\.w)).count < hindi.count,
                "1.18 should contain a repeated word")
    }

    @Test("Every enriched verse glosses both languages to the same length")
    func languagesAgree() throws {
        for verse in try ContentDatabase().allVerses() where verse.isEnriched {
            let hindi = verse.words(for: .sanskrit)
            let english = verse.words(for: .english)
            #expect(!hindi.isEmpty, "\(verse.reference) has no glosses")
            #expect(hindi.count == english.count,
                    "\(verse.reference): \(hindi.count) Hindi vs \(english.count) English")
        }
    }
}

/// The reference, in the script being read.
///
/// Worth pinning because the fault it replaces was invisible: `reference` is
/// ASCII and reads perfectly well on its own, so "2.47" under a Devanagari
/// shloka looks like a design choice rather than a setting that was missed.
/// Nothing fails, nothing logs; it just quietly stops being one language.
@Suite("Verse reference")
struct VerseReferenceTests {

    private func verse(_ chapter: Int, _ sutra: Int) -> Verse {
        Verse(id: 1, chapter: chapter, sutra: sutra, sanskrit: "…")
    }

    @Test("English keeps ASCII digits")
    func englishReference() {
        #expect(verse(2, 47).reference(devanagari: false) == "2.47")
        #expect(verse(18, 78).reference(devanagari: false) == "18.78")
    }

    @Test("Devanagari carries all the way through the numerals")
    func devanagariReference() {
        #expect(verse(2, 47).reference(devanagari: true) == "२.४७")
        #expect(verse(1, 1).reference(devanagari: true) == "१.१")
        #expect(verse(18, 78).reference(devanagari: true) == "१८.७८")
    }

    /// Not one ASCII digit survives a Devanagari reference — the assertion the
    /// per-case ones above would each pass while the app still showed "2.47"
    /// somewhere, if the helper were ever half-applied.
    @Test("No Devanagari reference contains a Latin digit")
    func noLatinDigitsLeak() throws {
        for chapter in 1 ... 18 {
            for sutra in 1 ... 78 {
                let written = verse(chapter, sutra).reference(devanagari: true)
                #expect(!written.contains { $0.isASCII && $0.isNumber },
                        "\(chapter).\(sutra) kept a Latin digit: \(written)")
            }
        }
    }

    /// The ASCII form stays ASCII: accessibility identifiers and notification
    /// request ids are built from it, and neither may move with a setting.
    @Test("The plain reference is unaffected by language")
    func plainReferenceIsStable() {
        #expect(verse(2, 47).reference == "2.47")
    }
}
