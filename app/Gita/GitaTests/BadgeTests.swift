//
//  BadgeTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

/// Badges reduce to one pure function from a snapshot to a set of ids, which is
/// why none of this needs a database, a clock or a running app.
struct BadgeTests {

    private static let chapters = Dictionary(
        uniqueKeysWithValues: [
            (1, 47), (2, 72), (3, 43), (4, 42), (5, 29), (6, 47), (7, 30), (8, 28), (9, 34),
            (10, 42), (11, 55), (12, 20), (13, 35), (14, 27), (15, 20), (16, 24), (17, 28), (18, 78),
        ]
    )

    private func snapshot(
        read: Set<Int> = [], perChapter: [Int: Int] = [:],
        current: Int = 0, longest: Int = 0, days: Int = 0
    ) -> ProgressSnapshot {
        ProgressSnapshot(
            readVerseIDs: read, versesReadPerChapter: perChapter,
            versesPerChapter: Self.chapters,
            currentStreak: current, longestStreak: longest, daysRead: days
        )
    }

    // MARK: - The catalogue itself

    @Test func theCatalogueIsTheAdvertisedSize() {
        #expect(BadgeCatalog.all.count == 35)
        #expect(BadgeCatalog.all(in: .verses).count == 7)
        #expect(BadgeCatalog.all(in: .chapters).count == 18)
        #expect(BadgeCatalog.all(in: .streaks).count == 4)
        #expect(BadgeCatalog.all(in: .landmarks).count == 6)
    }

    /// Ids are the database key. A duplicate would silently merge two badges.
    @Test func everyIdIsUnique() {
        #expect(Set(BadgeCatalog.all.map(\.id)).count == BadgeCatalog.all.count)
    }

    @Test func everyBadgeHasBothLanguages() {
        for badge in BadgeCatalog.all {
            #expect(!badge.titleSa.isEmpty, "\(badge.id) has no Sanskrit title")
            #expect(!badge.titleEn.isEmpty, "\(badge.id) has no English title")
            #expect(!badge.detailSa.isEmpty, "\(badge.id) has no Sanskrit detail")
            #expect(!badge.detailEn.isEmpty, "\(badge.id) has no English detail")
        }
    }

    // MARK: - Nothing for nothing

    /// The property that catches a requirement accidentally written as `>= 0`.
    @Test func anEmptySnapshotEarnsNothing() {
        #expect(Badge.earned(by: .empty).isEmpty)
        #expect(Badge.earned(by: snapshot()).isEmpty)
    }

    // MARK: - Verse milestones

    @Test(arguments: [(1, 1), (10, 2), (50, 3), (100, 4), (250, 5), (500, 6), (701, 7)])
    func verseMilestonesUnlockInOrder(read: Int, expected: Int) {
        let earned = Badge.earned(by: snapshot(read: Set(1 ... read)))
        let milestones = earned.filter { $0.hasPrefix("verses_") }
        #expect(milestones.count == expected, "\(read) verses should earn \(expected) milestones")
    }

    @Test func theFinalMilestoneNeedsTheWholeBook() {
        #expect(!Badge.earned(by: snapshot(read: Set(1 ... 700))).contains("verses_701"))
        #expect(Badge.earned(by: snapshot(read: Set(1 ... 701))).contains("verses_701"))
    }

    // MARK: - Chapters

    /// Exactly `verseCount` completes a chapter. An off-by-one here makes a
    /// badge that can never be earned.
    @Test func aChapterBadgeNeedsEveryVerseInIt() {
        #expect(!Badge.earned(by: snapshot(perChapter: [1: 46])).contains("chapter_1"))
        #expect(Badge.earned(by: snapshot(perChapter: [1: 47])).contains("chapter_1"))
    }

    @Test func chapterBadgesAreIndependent() {
        let earned = Badge.earned(by: snapshot(perChapter: [1: 47, 12: 20]))
        #expect(earned.contains("chapter_1"))
        #expect(earned.contains("chapter_12"))
        #expect(!earned.contains("chapter_2"))
    }

    // MARK: - Streaks

    @Test func streakBadgesUseTheLongestNotTheCurrent() {
        // Streak broken today, but the record stands — and so must the badge.
        let earned = Badge.earned(by: snapshot(current: 0, longest: 30))
        #expect(earned.contains("streak_7"))
        #expect(earned.contains("streak_30"))
        #expect(!earned.contains("streak_100"))
    }

    // MARK: - Landmarks

    @Test func landmarksUnlockOnReachingThatVerse() {
        #expect(Badge.earned(by: snapshot(read: [94])).contains("landmark_2.47"))
        #expect(!Badge.earned(by: snapshot(read: [93])).contains("landmark_2.47"))
    }

    /// Landmarks are earned out of order — someone who jumps straight to 18.66
    /// has still reached it.
    @Test func aLandmarkNeedsNoOtherProgress() {
        let earned = Badge.earned(by: snapshot(read: [689]))
        #expect(earned.contains("landmark_18.66"))
        #expect(!earned.contains("landmark_2.47"))
    }

    // MARK: - Invariants

    /// Progress only ever adds. A badge that can be taken away means a
    /// requirement was written with `==` instead of `>=`.
    @Test func earningIsMonotonic() {
        var previous = Set<String>()
        for read in stride(from: 0, through: 701, by: 37) {
            let earned = Badge.earned(by: snapshot(
                read: read == 0 ? [] : Set(1 ... read),
                perChapter: [1: min(read, 47)],
                current: read / 20, longest: read / 20
            ))
            #expect(previous.isSubset(of: earned), "badges were lost at \(read) verses")
            previous = earned
        }
    }

    /// Every badge must be reachable by some plausible reader, or it is
    /// decoration pretending to be a goal.
    @Test func everyBadgeIsReachable() {
        let finished = snapshot(
            read: Set(1 ... 701),
            perChapter: Self.chapters,
            current: 365, longest: 365, days: 365
        )
        let earned = Badge.earned(by: finished)
        #expect(earned.count == BadgeCatalog.all.count)
    }

    /// The landmark ids point at real verses in the shipped corpus — a typo
    /// here would make a badge quietly unearnable.
    @Test func landmarkVerseIDsMatchTheirReferences() throws {
        let verses = try #require(try? ContentDatabase().allVerses())
        let byID = Dictionary(uniqueKeysWithValues: verses.map { ($0.id, $0) })

        for badge in BadgeCatalog.all(in: .landmarks) {
            guard case .verseReached(let verseID) = badge.requirement else {
                Issue.record("\(badge.id) is not a verse requirement")
                continue
            }
            let verse = try #require(byID[verseID], "\(badge.id) points at no verse")
            let reference = badge.id.replacingOccurrences(of: "landmark_", with: "")
            #expect("\(verse.chapter).\(verse.sutra)" == reference,
                    "\(badge.id) points at \(verse.chapter).\(verse.sutra)")
        }
    }
}

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Every badge names an SF Symbol. A misspelled one does not fail to build and
/// does not throw — it simply draws nothing, leaving a blank circle in the grid
/// that no other test would notice.
struct BadgeSymbolTests {

    private func symbolExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIImage(systemName: name) != nil
        #elseif canImport(AppKit)
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        #else
        true
        #endif
    }

    @Test func everySymbolResolves() {
        for badge in BadgeCatalog.all {
            #expect(symbolExists(badge.symbol), "\(badge.id) uses a symbol that does not exist: \(badge.symbol)")
        }
    }

    /// Eighteen chapters, eighteen different icons — the point of giving them
    /// their own symbols in the first place.
    @Test func everyChapterHasItsOwnSymbol() {
        let symbols = BadgeCatalog.all(in: .chapters).map(\.symbol)
        #expect(Set(symbols).count == symbols.count, "two chapters share a symbol")
    }
}
