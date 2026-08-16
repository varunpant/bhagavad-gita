//
//  ProgressMathTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

/// `ProgressSnapshot` is a plain struct, so the arithmetic the progress screen
/// shows can be checked without a database or a running app.
struct ProgressMathTests {

    /// A small stand-in corpus: three chapters of 10, 20 and 5 verses.
    private static let chapters = [1: 10, 2: 20, 3: 5]

    private func snapshot(read: Set<Int>, perChapter: [Int: Int]) -> ProgressSnapshot {
        ProgressSnapshot(
            readVerseIDs: read,
            versesReadPerChapter: perChapter,
            versesPerChapter: Self.chapters,
            currentStreak: 0, longestStreak: 0
        )
    }

    @Test func emptyProgressIsZeroNotNaN() {
        #expect(ProgressSnapshot.empty.completion == 0)
        #expect(ProgressSnapshot.empty.versesRead == 0)
        #expect(ProgressSnapshot.empty.totalVerses == 0)
    }

    /// The denominator comes from the chapters, so an unloaded corpus divides
    /// by nothing and must not produce NaN — a NaN reaches the ring as a blank
    /// screen rather than as an error.
    @Test func completionWithNoCorpusIsZero() {
        let unloaded = ProgressSnapshot(
            readVerseIDs: [1, 2, 3], versesReadPerChapter: [1: 3], versesPerChapter: [:],
            currentStreak: 0, longestStreak: 0
        )
        #expect(unloaded.completion == 0)
        #expect(!unloaded.completion.isNaN)
    }

    @Test func totalIsTheSumOfChapterSizes() {
        #expect(snapshot(read: [], perChapter: [:]).totalVerses == 35)
    }

    @Test func completionIsReadOverTotal() {
        let half = snapshot(read: Set(1 ... 7), perChapter: [1: 7])
        #expect(abs(half.completion - 7.0 / 35.0) < 0.000_1)
    }

    @Test func chapterCompletionUsesThatChaptersSize() {
        let progress = snapshot(read: Set(1 ... 5), perChapter: [1: 5])
        #expect(abs(progress.completion(ofChapter: 1) - 0.5) < 0.000_1)
        #expect(progress.completion(ofChapter: 2) == 0)
    }

    /// Exactly `verseCount` completes a chapter — an off-by-one here means a
    /// chapter badge that can never unlock.
    @Test func aChapterIsCompleteAtExactlyItsVerseCount() {
        let progress = snapshot(read: Set(1 ... 10), perChapter: [1: 10])
        #expect(progress.isComplete(chapter: 1))
        #expect(!progress.isComplete(chapter: 2))
    }

    @Test func anUnknownChapterIsNeverComplete() {
        #expect(!snapshot(read: [], perChapter: [:]).isComplete(chapter: 99))
    }

    /// The real corpus is 701 verses, not the 700 everyone expects: the source
    /// splits 13.1 into two rows. Anything that hardcodes 700 leaves the ring
    /// permanently one verse short of full.
    @Test func theRealCorpusIsSevenHundredAndOne() throws {
        let database = try #require(try? ContentDatabase())
        let chapters = try database.allChapters()
        #expect(chapters.count == 18)
        #expect(chapters.reduce(0) { $0 + $1.verseCount } == 701)
    }

    /// Per-chapter counts must sum to the overall count, or the chapter list
    /// and the ring will disagree on screen.
    /// `@MainActor` because `ReadingProgress` is: it is observable UI state,
    /// and the only thing it does off the main actor is the database write.
    @MainActor
    @Test func chapterCountsSumToTheTotal() throws {
        let database = try #require(try? ContentDatabase())
        let verses = try database.allVerses()

        // A throwaway store: `ReadingProgress(store: nil)` would open the
        // real user.sqlite and write test data into it.
        let progress = ReadingProgress(store: try UserDatabase(url: TempStore.url()))
        progress.adopt(verses: verses, chapters: try database.allChapters())
        for verse in verses.prefix(120) { progress.record(verse.id) }

        let snapshot = progress.snapshot
        #expect(snapshot.versesRead == 120)
        #expect(snapshot.versesReadPerChapter.values.reduce(0, +) == 120)
    }
}
