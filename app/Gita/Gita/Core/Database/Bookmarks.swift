//
//  Bookmarks.swift
//  Gita
//

import Foundation
import Observation
import OSLog

/// Verses the reader has kept.
///
/// Held as a set in memory and written through to `user.sqlite` on each change:
/// the reader asks "is this one bookmarked?" on every verse it draws, and that
/// question must not touch the database.
@Observable
final class Bookmarks {
    private(set) var verseIDs: Set<Int> = []
    private let store: UserDatabase?

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "Bookmarks"
    )

    init(store: UserDatabase? = nil) {
        do {
            let database = try store ?? UserDatabase()
            self.store = database
            verseIDs = (try? database.bookmarkedVerseIDs()) ?? []
        } catch {
            self.store = nil
            Self.logger.error("No bookmark store: \(error.localizedDescription)")
        }
    }

    func contains(_ verseID: Int) -> Bool { verseIDs.contains(verseID) }

    /// Returns what the verse became, so the caller can pick its feedback.
    @discardableResult
    func toggle(_ verseID: Int) -> Bool {
        let bookmarked = !verseIDs.contains(verseID)
        if bookmarked { verseIDs.insert(verseID) } else { verseIDs.remove(verseID) }

        // The set is the truth the UI reads, and the write goes with it rather
        // than onto a task. Backgrounding suspends the app before an
        // unstructured task is scheduled, so a verse kept and then put down was
        // never kept at all — the same defect `ReadingProgress.record`
        // documents at length.
        if let store {
            do {
                if bookmarked { try store.addBookmark(verseID) }
                else { try store.removeBookmark(verseID) }
            } catch {
                Self.logger.error("Could not save bookmark: \(error.localizedDescription)")
            }
        }
        return bookmarked
    }
}
