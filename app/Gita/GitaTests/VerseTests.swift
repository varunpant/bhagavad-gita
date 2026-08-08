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

    @Test("A speaker attribution always stands on its own line")
    func speakerOnItsOwnLine() throws {
        for verse in try ContentDatabase().allVerses() {
            for line in verse.lines where line.contains("उवाच") && !Verse.isSpeaker(line) {
                // 1.25 is the sole legitimate case: "उवाच" there is a verb
                // mid-verse, not an attribution.
                #expect(verse.reference == "1.25", "\(verse.reference) has उवाच run into the verse")
            }
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
