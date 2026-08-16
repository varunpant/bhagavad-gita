//
//  ProgressSnapshot.swift
//  Gita
//

import Foundation

/// Everything the app knows about how far the reader has got, as one value.
///
/// This exists so that the interesting questions — what is my completion, which
/// badges have I earned — are pure functions of a plain struct rather than
/// methods on something that owns a database. A snapshot can be written by hand
/// in a test in four lines, which is what makes the badge catalogue and the
/// progress arithmetic testable without a store, a clock or a running app.
nonisolated struct ProgressSnapshot: Equatable, Sendable {
    /// Verse IDs (1...701) that have been read at least once.
    let readVerseIDs: Set<Int>
    /// Chapter number → verses read in it. Derived once here rather than
    /// recomputed by every caller that wants a chapter bar.
    let versesReadPerChapter: [Int: Int]
    /// Chapter number → how many verses it holds, from the bundled corpus.
    let versesPerChapter: [Int: Int]
    let currentStreak: Int
    let longestStreak: Int
    let daysRead: Int

    static let empty = ProgressSnapshot(
        readVerseIDs: [], versesReadPerChapter: [:], versesPerChapter: [:],
        currentStreak: 0, longestStreak: 0, daysRead: 0
    )

    // MARK: - Totals

    var versesRead: Int { readVerseIDs.count }

    /// The size of the corpus, taken from the chapters rather than hardcoded.
    ///
    /// It is **701**, not the 700 everyone expects: the source splits 13.1 into
    /// two rows. Writing `700` anywhere would leave the ring permanently one
    /// verse short of full, which is the kind of bug nobody reports and
    /// everybody notices.
    var totalVerses: Int { versesPerChapter.values.reduce(0, +) }

    /// 0...1. Zero when the corpus has not loaded, rather than a divide by zero.
    var completion: Double {
        guard totalVerses > 0 else { return 0 }
        return Double(versesRead) / Double(totalVerses)
    }

    // MARK: - Chapters

    func versesRead(inChapter chapter: Int) -> Int { versesReadPerChapter[chapter] ?? 0 }

    func completion(ofChapter chapter: Int) -> Double {
        guard let total = versesPerChapter[chapter], total > 0 else { return 0 }
        return Double(versesRead(inChapter: chapter)) / Double(total)
    }

    func isComplete(chapter: Int) -> Bool {
        guard let total = versesPerChapter[chapter], total > 0 else { return false }
        return versesRead(inChapter: chapter) >= total
    }

    /// Chapters finished end to end.
    var completedChapters: Int {
        versesPerChapter.keys.count { isComplete(chapter: $0) }
    }
}
