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

    /// Day → verses first read that day. `readingDays` says *whether* a day was
    /// read on, which is all a streak needs; the widget's bar chart needs how
    /// much, and the store has been keeping the count all along.
    private(set) var readingDayCounts: [String: Int] = [:]

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
            readingDayCounts = (try? database.readingDayCounts()) ?? [:]
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
        // Uneven on purpose: six identical bars in the widget's chart would
        // show nothing about how the days differ, which is what it is for.
        readingDayCounts = Dictionary(
            uniqueKeysWithValues: zip(readingDays, [9, 14, 3, 22, 11, 26])
        )
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
            readingDayCounts[day, default: 0] += 1
            if readingDays.last != day, !readingDays.contains(day) {
                readingDays.append(day)
                readingDays.sort()
            }
        }

        // Written now, not on a task.
        //
        // This used to be `Task { @concurrent in … }`, and the verse would be
        // read for the rest of the session and unread ever after: iOS suspends
        // an app when it goes to the background and kills it from the switcher
        // without ever scheduling that task, so the row was never inserted.
        // Reading the last verse of a session and then putting the phone down
        // lost it every time — which is exactly what "I read it but it is not
        // marked" looks like from the outside.
        //
        // The cost is one small INSERT on the main actor, at most once per
        // verse ever read. That is worth a great deal less than the read.
        // Every read, not only the first: `recordRead` keeps `lastReadAt` and
        // `readCount` for re-reads, which costs one statement. Seeded design
        // progress is the one thing that must not reach the store.
        if let store, !isDesignSeed {
            do {
                try store.recordRead(verseID, on: day, at: date)
            } catch {
                Self.logger.error("Could not record read: \(error.localizedDescription)")
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

        // Written now rather than on a task, for the reason spelled out in
        // `record`: a badge earned on the last verse before the phone goes in a
        // pocket was being lost.
        if let store, !isDesignSeed {
            do {
                try store.unlockBadges(fresh)
            } catch {
                Self.logger.error("Could not save badges: \(error.localizedDescription)")
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
        readingDayCounts = [:]
        unlockedBadgeIDs = []
        newlyEarned = []

        if let store {
            do {
                try store.resetProgress()
            } catch {
                Self.logger.error("Could not reset progress: \(error.localizedDescription)")
            }
        }
    }
}
