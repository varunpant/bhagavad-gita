//
//  UserDatabase+Progress.swift
//  Gita
//

import Foundation
import GRDB

/// Reading progress: which verses have been read, and on which days.
///
/// Deliberately **two tables and no aggregate**. RigVeda keeps a `user_stats`
/// singleton holding a dozen pre-computed counters — totals, current streak,
/// longest streak — updated by hand on every write. That is a second source of
/// truth, and the only thing it can do that these two tables cannot is
/// disagree with them. Counting 701 rows costs nothing; derive on read.
/// `nonisolated` is not inherited from the declaration in
/// `UserDatabase.swift`. With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` an
/// extension declared elsewhere is main-actor by default, which would pull
/// every query here back onto the main thread — silently, since it compiles
/// until something tries to call it off the main actor.
nonisolated extension UserDatabase {

    /// Registered from `UserDatabase.migrator`. Append-only, like every
    /// migration before it.
    static func registerProgress(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("createProgress") { db in
            // Keyed by verse, not append-only: re-reading 2.47 updates the row
            // it already has. A log of every read would grow without bound and
            // answer no question the app actually asks.
            try db.create(table: "verseReads") { table in
                table.primaryKey("verseId", .integer)
                table.column("firstReadAt", .datetime).notNull()
                table.column("lastReadAt", .datetime).notNull()
                table.column("readCount", .integer).notNull().defaults(to: 1)
            }

            // `day` is a local-calendar date string. Storing UTC instead would
            // break the streak of anyone who reads late in the evening, which
            // is most people.
            try db.create(table: "readingDays") { table in
                table.primaryKey("day", .text)
                table.column("versesRead", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "badges") { table in
                table.primaryKey("badgeId", .text)
                table.column("unlockedAt", .datetime).notNull()
                table.column("seen", .boolean).notNull().defaults(to: false)
            }
        }
    }

    // MARK: - Recording

    /// Marks a verse read, and returns whether this was the **first** time.
    ///
    /// The return value is what the caller needs: only a first read advances
    /// any total, so only a first read can unlock a badge or extend a streak.
    /// Re-reads still update `lastReadAt` and `readCount`, which is worth
    /// having and costs one statement.
    @discardableResult
    func recordRead(_ verseID: Int, on day: String, at date: Date = Date()) throws -> Bool {
        try queue.write { db in
            let existing = try Int.fetchOne(
                db, sql: "SELECT readCount FROM verseReads WHERE verseId = ?", arguments: [verseID]
            )

            guard existing == nil else {
                try db.execute(
                    sql: """
                        UPDATE verseReads SET lastReadAt = ?, readCount = readCount + 1
                        WHERE verseId = ?
                        """,
                    arguments: [date, verseID]
                )
                return false
            }

            try db.execute(
                sql: """
                    INSERT INTO verseReads (verseId, firstReadAt, lastReadAt, readCount)
                    VALUES (?, ?, ?, 1)
                    """,
                arguments: [verseID, date, date]
            )
            // Upsert rather than insert-then-update: the first verse of the day
            // creates the row, the rest increment it, in one statement either way.
            try db.execute(
                sql: """
                    INSERT INTO readingDays (day, versesRead) VALUES (?, 1)
                    ON CONFLICT(day) DO UPDATE SET versesRead = versesRead + 1
                    """,
                arguments: [day]
            )
            return true
        }
    }

    // MARK: - Reading

    func readVerseIDs() throws -> Set<Int> {
        try queue.read { db in
            Set(try Int.fetchAll(db, sql: "SELECT verseId FROM verseReads"))
        }
    }

    /// Every day with at least one first read, oldest first. The streak
    /// functions take it from here.
    func readingDays() throws -> [String] {
        try queue.read { db in
            try String.fetchAll(db, sql: "SELECT day FROM readingDays ORDER BY day ASC")
        }
    }

    /// Day → verses first read that day, for the activity heatmap.
    func readingDayCounts() throws -> [String: Int] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT day, versesRead FROM readingDays")
                .reduce(into: [:]) { $0[$1["day"] as String] = $1["versesRead"] as Int }
        }
    }

    // MARK: - Badges

    func unlockedBadgeIDs() throws -> Set<String> {
        try queue.read { db in
            Set(try String.fetchAll(db, sql: "SELECT badgeId FROM badges"))
        }
    }

    func unlockBadges(_ ids: some Collection<String>, at date: Date = Date()) throws {
        guard !ids.isEmpty else { return }
        try queue.write { db in
            for id in ids {
                try db.execute(
                    sql: "INSERT OR IGNORE INTO badges (badgeId, unlockedAt, seen) VALUES (?, ?, 0)",
                    arguments: [id, date]
                )
            }
        }
    }

    // MARK: - Reset

    /// Erases progress and nothing else.
    ///
    /// Bookmarks and settings live in their own tables in this same file and
    /// are deliberately untouched — people conflate the two, and losing forty
    /// kept verses to a "reset progress" tap would be unforgivable.
    /// `ProgressStoreTests` asserts exactly that.
    func resetProgress() throws {
        try queue.write { db in
            try db.execute(sql: "DELETE FROM verseReads")
            try db.execute(sql: "DELETE FROM readingDays")
            try db.execute(sql: "DELETE FROM badges")
        }
    }
}
