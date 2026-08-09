//
//  ContentDatabase.swift
//  Gita
//

import Foundation
import GRDB
import OSLog

/// Read-only access to the bundled `gita.sqlite`.
///
/// The file is opened **in place** inside the app bundle — it is never copied
/// into a container, because nothing ever writes to it. User data lives in a
/// separate writable store (specs.md section 4.2).
///
/// `nonisolated` so reads happen off the main actor; GRDB serializes access
/// internally, and every value returned across the boundary is `Sendable`.
nonisolated struct ContentDatabase {
    enum Failure: Error, LocalizedError {
        case notBundled

        var errorDescription: String? {
            switch self {
            case .notBundled:
                "gita.sqlite is missing from the app bundle. Run tools/build_db.py."
            }
        }
    }

    private let queue: DatabaseQueue
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "ContentDatabase"
    )

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "gita", withExtension: "sqlite") else {
            throw Failure.notBundled
        }
        var configuration = Configuration()
        configuration.readonly = true
        queue = try DatabaseQueue(path: url.path, configuration: configuration)

        Self.logger.debug("Opened bundled content database at \(url.lastPathComponent)")
    }

    /// Every verse, in reading order — chapter 1 verse 1 through chapter 18.
    ///
    /// The whole corpus is Sanskrit-only at this stage: 701 rows, a few hundred
    /// kilobytes. Reading it in one pass is cheaper than paging, and it lets the
    /// reader move between any two verses instantly. Revisit when the Hindi
    /// commentary lands, which is an order of magnitude more text.
    func allVerses() throws -> [Verse] {
        try queue.read { db in
            try Verse.order(Column("chapter"), Column("sutra")).fetchAll(db)
        }
    }

    /// The eighteen chapters, in order.
    func allChapters() throws -> [Chapter] {
        try queue.read { db in try Chapter.order(Column("id")).fetchAll(db) }
    }

    /// Full-text search across every column the reader can see.
    ///
    /// The query is rebuilt as a quoted prefix expression rather than passed
    /// through: FTS5's syntax would otherwise treat a stray quote, `*` or `NOT`
    /// as an operator, and a reader typing an apostrophe would get a crash
    /// instead of results.
    func search(_ query: String, limit: Int = 80) throws -> [SearchHit] {
        let terms = query
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return [] }

        let expression = terms.map { "\"\($0)\"*" }.joined(separator: " AND ")

        return try queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT verses.*, snippet(verses_fts, -1, '\u{2062}', '\u{2063}', '…', 12) AS snippet
                FROM verses_fts
                JOIN verses ON verses.id = verses_fts.rowid
                WHERE verses_fts MATCH ?
                ORDER BY rank
                LIMIT ?
                """, arguments: [expression, limit])
                .map { row in
                    SearchHit(verse: try! Verse(row: row), snippet: row["snippet"] ?? "")
                }
        }
    }

    /// Version stamp written by `tools/build_db.py`.
    func contentVersion() throws -> String? {
        try queue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'content_version'")
        }
    }
}
