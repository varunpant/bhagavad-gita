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

    /// Every badge the snapshot has earned. Pure; the caller decides what is
    /// newly earned by diffing against what is already stored.
    nonisolated static func earned(
        by snapshot: ProgressSnapshot, from catalogue: [Badge] = BadgeCatalog.all
    ) -> Set<String> {
        Set(catalogue.filter { $0.isEarned(by: snapshot) }.map(\.id))
    }
}
