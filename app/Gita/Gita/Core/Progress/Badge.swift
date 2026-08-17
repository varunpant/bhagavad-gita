//
//  Badge.swift
//  Gita
//

import Foundation

/// Something the reader has earned.
///
/// A value type with a declarative requirement, so the whole system reduces to
/// one pure function from a `ProgressSnapshot` to a set of ids. Everything
/// else — the store, the grid, the toast — is plumbing around that function,
/// and the function needs no database, no clock and no running app to test.
nonisolated struct Badge: Identifiable, Hashable, Sendable {

    enum Family: String, CaseIterable, Sendable {
        case verses, chapters, streaks, landmarks

        func title(isDevanagari: Bool) -> String {
            switch self {
            case .verses:    isDevanagari ? "श्लोक" : "VERSES"
            case .chapters:  isDevanagari ? "अध्याय" : "CHAPTERS"
            case .streaks:   isDevanagari ? "निरंतरता" : "STREAKS"
            case .landmarks: isDevanagari ? "विशेष श्लोक" : "LANDMARKS"
            }
        }
    }

    /// What has to be true for the badge to unlock.
    ///
    /// Every case is a `>=` comparison or a set membership — never `==`. An
    /// equality here would make a badge unreachable for anyone who passed the
    /// threshold in one go, which is exactly the bug `BadgeTests` guards with
    /// its monotonicity check.
    enum Requirement: Hashable, Sendable {
        case versesRead(Int)
        case chapterComplete(Int)
        case currentStreak(Int)
        /// Reaching one particular verse, by global id.
        case verseReached(Int)
    }

    let id: String
    let titleSa: String
    let titleEn: String
    let detailSa: String
    let detailEn: String
    let symbol: String
    let family: Family
    let requirement: Requirement

    func title(isDevanagari: Bool) -> String { isDevanagari ? titleSa : titleEn }
    func detail(isDevanagari: Bool) -> String { isDevanagari ? detailSa : detailEn }

    // MARK: - Evaluation

    func isEarned(by snapshot: ProgressSnapshot) -> Bool {
        switch requirement {
        case .versesRead(let count):
            snapshot.versesRead >= count
        case .chapterComplete(let chapter):
            snapshot.isComplete(chapter: chapter)
        case .currentStreak(let days):
            // Against the *longest* streak, not the current one. A badge is a
            // record of something achieved; taking it away again because
            // someone missed a Tuesday would be a punishment, not a reward.
            snapshot.longestStreak >= days
        case .verseReached(let verseID):
            snapshot.readVerseIDs.contains(verseID)
        }
    }

    // MARK: - Standing

    /// How close the reader is to earning this badge.
    ///
    /// `isEarned` alone answers "have I got it"; a reader looking at a locked
    /// badge is asking the other question — how far off am I. Pure, like
    /// `isEarned`, so the arithmetic is testable without a store or a view.
    struct Standing: Equatable, Sendable {
        let current: Int
        let target: Int
        /// Whether counting says anything. A landmark verse is reached or it is
        /// not; "0 of 1" is a worse answer than none at all.
        let isCountable: Bool

        /// `target > 0` is not pedantry: before the corpus loads a chapter's
        /// size is unknown, and "0 of 0" would otherwise report every chapter
        /// badge as earned — which is exactly what `isComplete(chapter:)`
        /// guards against on the snapshot.
        var isEarned: Bool { target > 0 && current >= target }
        /// 0...1, clamped — passing a threshold in one go must not overfill a bar.
        var fraction: Double {
            guard target > 0 else { return 0 }
            return min(1, Double(current) / Double(target))
        }
    }

    func standing(in snapshot: ProgressSnapshot) -> Standing {
        switch requirement {
        case .versesRead(let count):
            Standing(current: snapshot.versesRead, target: count, isCountable: true)
        case .chapterComplete(let chapter):
            Standing(current: snapshot.versesRead(inChapter: chapter),
                     target: snapshot.versesPerChapter[chapter] ?? 0,
                     isCountable: true)
        case .currentStreak(let days):
            // The longest streak, matching `isEarned` — showing the current one
            // here would put a locked badge next to a bar that had just gone
            // backwards through no fault of the reader's.
            Standing(current: snapshot.longestStreak, target: days, isCountable: true)
        case .verseReached(let verseID):
            Standing(current: snapshot.readVerseIDs.contains(verseID) ? 1 : 0,
                     target: 1, isCountable: false)
        }
    }

    /// Every badge the snapshot has earned. Pure; the caller decides what is
    /// newly earned by diffing against what is already stored.
    nonisolated static func earned(
        by snapshot: ProgressSnapshot, from catalogue: [Badge] = BadgeCatalog.all
    ) -> Set<String> {
        Set(catalogue.filter { $0.isEarned(by: snapshot) }.map(\.id))
    }
}
