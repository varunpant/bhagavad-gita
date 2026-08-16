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

    /// Earned just now and not yet shown. The view clears it once the toast
    /// has been seen; nothing else reads it.
    var newlyEarned: [Badge] = []

    /// Chapter sizes, handed over once the corpus loads. Until then the
    /// snapshot reports a total of zero and a completion of zero rather than
    /// dividing by nothing.
    private var versesPerChapter: [Int: Int] = [:]

    /// Verse id → chapter. A snapshot has no other way to bucket a bare set of
    /// ids into chapters.
    private var chapterOf: [Int: Int] = [:]

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

        #if DEBUG
        // Plausible progress for design review and screenshots: an empty
        // Progress screen shows none of the things it exists to show.
        if ProcessInfo.processInfo.arguments.contains("-seedProgress") { seedForDesign() }
        #endif
    }

    /// Seeded progress must never reach the store, or a screenshot run would
    /// leave fake badges in the reader's real database.
    private var isDesignSeed = false

    #if DEBUG
    /// Chapter 1 finished, most of chapter 2, a scattering beyond, and a
    /// six-day streak ending today. In memory only — never written to the store.
    private func seedForDesign() {
        isDesignSeed = true
        readVerseIDs = Set(1 ... 47).union(Set(48 ... 80)).union([120, 121, 300, 301, 302])
        let today = Date()
        readingDays = (0 ..< 6)
            .compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
            .map { Streak.day(for: $0) }
            .sorted()
    }
    #endif

    // MARK: - Corpus

    /// Takes both halves of the corpus at once, once it has loaded.
    ///
    /// Deliberately **not** two calls. Chapter badges are judged from the
    /// chapter sizes *and* the verse-to-chapter map, so two setters could be
    /// called in the order that judges them against a map that is still empty —
    /// awarding nothing, and never running again. One call cannot be
    /// misordered.
    ///
    /// Progress is meaningful before this: the counts are real from the first
    /// verse read. Only completion needs a denominator.
    func adopt(verses: [Verse], chapters: [Chapter]) {
        chapterOf = Dictionary(
            verses.map { ($0.id, $0.chapter) }, uniquingKeysWith: { first, _ in first }
        )
        versesPerChapter = Dictionary(
            chapters.map { ($0.id, $0.verseCount) }, uniquingKeysWith: { first, _ in first }
        )
        // Settles anything earned by reading done before the corpus could
        // judge it — without this, finishing a chapter and relaunching would
        // lose the badge.
        awardBadges(announcing: false)
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
            longestStreak: Streak.longest(from: readingDays)
        )
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

        // Only a first read can move a total, so only a first read can earn
        // anything. Re-reading familiar ground stays free.
        if isFirst { awardBadges(announcing: true) }
        return isFirst
    }

    /// Diffs what the current snapshot has earned against what is already
    /// stored, and keeps the difference.
    ///
    /// Badges are never revoked: only additions are taken. Losing a streak must
    /// not take the badge back — see `Badge.isEarned`, which tests streaks
    /// against the longest ever rather than the current one.
    /// - Parameter announcing: whether to raise a toast. False when settling
    ///   badges that were earned earlier and are only now computable — nobody
    ///   wants six toasts on launch for work they did last week.
    private func awardBadges(announcing: Bool) {
        let earned = Badge.earned(by: snapshot)
        let fresh = earned.subtracting(unlockedBadgeIDs)
        guard !fresh.isEmpty else { return }

        unlockedBadgeIDs.formUnion(fresh)
        if announcing {
            newlyEarned += BadgeCatalog.all.filter { fresh.contains($0.id) }
        }

        if let store, !isDesignSeed {
            Task { @concurrent in
                do {
                    try store.unlockBadges(fresh)
                } catch {
                    Self.logger.error("Could not save badges: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Reset

    /// Erases progress. Bookmarks and settings are untouched — that promise is
    /// made to the reader in the confirmation dialog, so it is kept here and
    /// asserted in `ProgressStoreTests`.
    func reset() {
        readVerseIDs = []
        readingDays = []
        unlockedBadgeIDs = []
        newlyEarned = []

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
