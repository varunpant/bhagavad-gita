//
//  VerseTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

@Suite("Verse line breaking")
struct VerseLineTests {

    @Test("Real newlines in the source are honoured")
    func newlinesWin() {
        let verse = Verse(
            id: 1, chapter: 1, sutra: 1,
            sanskrit: "धृतराष्ट्र उवाच\n\nधर्मक्षेत्रे कुरुक्षेत्रे समवेता युयुत्सवः।\n\nमामकाः पाण्डवाश्चैव किमकुर्वत सञ्जय।।1.1।।"
        )
        #expect(verse.lines == [
            "धृतराष्ट्र उवाच",
            "धर्मक्षेत्रे कुरुक्षेत्रे समवेता युयुत्सवः।",
            "मामकाः पाण्डवाश्चैव किमकुर्वत सञ्जय।।1.1।।",
        ])
    }

    @Test("A single-line shloka breaks on the danda, keeping the reference marker")
    func dandaSplit() {
        let verse = Verse(
            id: 60, chapter: 2, sutra: 47,
            sanskrit: "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।मा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि।।2.47।।"
        )
        #expect(verse.lines == [
            "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।",
            "मा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि।।2.47।।",
        ])
    }

    @Test("Breaking never loses or invents characters")
    func lossless() throws {
        let library = try ContentDatabase().allVerses()
        #expect(library.count == 701)

        for verse in library {
            let rejoined = verse.lines.joined()
            let original = verse.sanskrit
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: " ", with: "")
            #expect(
                rejoined.replacingOccurrences(of: " ", with: "") == original,
                "line breaking altered \(verse.reference)"
            )
        }
    }

    @Test("Reference is the traditional chapter.verse form")
    func reference() {
        #expect(Verse(id: 1, chapter: 2, sutra: 47, sanskrit: "x").reference == "2.47")
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
