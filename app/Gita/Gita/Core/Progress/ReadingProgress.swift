//
//  ReadingProgress.swift
//  Gita
//

import Foundation
import Observation
import OSLog

/// How far the reader has got, held in memory and written through to
/// `user.sqlite`.
///
/// Same shape as `Bookmarks`: the sets are what the UI reads, the database is a
/// background chore. The reader asks "have I read this?" for every verse it
/// draws, and that question must never touch disk.
@Observable
final class ReadingProgress {
    private(set) var readVerseIDs: Set<Int> = []
    private(set) var readingDays: [String] = []
    private(set) var unlockedBadgeIDs: Set<String> = []

    /// Chapter sizes, handed over once the corpus loads. Until then the
    /// snapshot reports a total of zero and a completion of zero rather than
    /// dividing by nothing.
    private(set) var versesPerChapter: [Int: Int] = [:]

    private let store: UserDatabase?

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "ReadingProgress"
    )

    init(store: UserDatabase? = nil) {
        do {
            let database = try store ?? UserDatabase()
            self.store = database
            readVerseIDs = (try? database.readVerseIDs()) ?? []
            readingDays = (try? database.readingDays()) ?? []
            unlockedBadgeIDs = (try? database.unlockedBadgeIDs()) ?? []
        } catch {
            self.store = nil
            Self.logger.error("No progress store: \(error.localizedDescription)")
        }
    }

    // MARK: - Corpus

    /// Called once the chapters load. Progress is meaningful without it — the
    /// counts are real — but completion needs a denominator.
    func adopt(chapters: [Chapter]) {
        versesPerChapter = Dictionary(
            chapters.map { ($0.id, $0.verseCount) }, uniquingKeysWith: { first, _ in first }
        )
    }

    // MARK: - Snapshot

    /// Recomputed on read rather than cached. `versesReadPerChapter` is one
    /// pass over at most 701 integers; caching it would mean invalidating it,
    /// and an invalidation bug here shows up as a progress bar that quietly
    /// stops moving.
    var snapshot: ProgressSnapshot {
        var perChapter: [Int: Int] = [:]
        for verseID in readVerseIDs {
            guard let chapter = chapterOf[verseID] else { continue }
            perChapter[chapter, default: 0] += 1
        }

        let today = Streak.day(for: Date())
        return ProgressSnapshot(
            readVerseIDs: readVerseIDs,
            versesReadPerChapter: perChapter,
            versesPerChapter: versesPerChapter,
            currentStreak: Streak.current(from: readingDays, today: today),
            longestStreak: Streak.longest(from: readingDays),
            daysRead: readingDays.count
        )
    }

    /// Verse ID → chapter. Built from the corpus once, because a snapshot
    /// otherwise has no way to bucket a bare set of IDs.
    private var chapterOf: [Int: Int] = [:]

    func adopt(verses: [Verse]) {
        chapterOf = Dictionary(verses.map { ($0.id, $0.chapter) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Recording

    func hasRead(_ verseID: Int) -> Bool { readVerseIDs.contains(verseID) }

    /// Marks a verse read. Returns whether this was the first time, since only
    /// a first read can move any total.
    @discardableResult
    func record(_ verseID: Int, at date: Date = Date()) -> Bool {
        let day = Streak.day(for: date)
        let isFirst = !readVerseIDs.contains(verseID)

        if isFirst {
            readVerseIDs.insert(verseID)
            if readingDays.last != day, !readingDays.contains(day) {
                readingDays.append(day)
                readingDays.sort()
            }
        }

        if let store {
            Task { @concurrent in
                do {
                    try store.recordRead(verseID, on: day, at: date)
                } catch {
                    Self.logger.error("Could not record read: \(error.localizedDescription)")
                }
            }
        }
        return isFirst
    }

    // MARK: - Reset

    /// Erases progress. Bookmarks and settings are untouched — that promise is
    /// made to the reader in the confirmation dialog, so it is kept here and
    /// asserted in `ProgressStoreTests`.
    func reset() {
        readVerseIDs = []
        readingDays = []
        unlockedBadgeIDs = []

        if let store {
            Task { @concurrent in
                do {
                    try store.resetProgress()
                } catch {
                    Self.logger.error("Could not reset progress: \(error.localizedDescription)")
                }
            }
        }
    }
}
