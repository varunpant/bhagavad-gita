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

    /// Longest query we will act on. A search box is an open door for pasted
    /// text; nothing useful is longer than this, and FTS5 degrades badly on
    /// hundred-term expressions.
    static let maxQueryLength = 128
    /// Terms beyond this are dropped. Each one becomes an AND clause, and the
    /// cost of the match grows with them.
    static let maxTerms = 8

    /// Reduce arbitrary user input to something safe to hand to FTS5.
    ///
    /// Three separate hazards, none of which are SQL injection — values are
    /// always bound, never interpolated — but all of which are real:
    ///
    /// * **FTS5's own expression language.** `*`, `^`, `:`, `-`, `NEAR`, `AND`,
    ///   parentheses and quotes are operators. Passed through, a lone `"` is a
    ///   syntax error and the query throws rather than returning nothing. Each
    ///   term is quoted, so every one is a literal.
    /// * **Length.** Pasted text is unbounded; the query is truncated by
    ///   scalars, not Characters, so a string of combining marks cannot smuggle
    ///   in megabytes behind a small visible length.
    /// * **Invisible and directional characters.** Zero-width joiners, bidi
    ///   overrides and control characters are stripped: they cannot match
    ///   anything in the corpus, and bidi overrides can reorder how a query
    ///   renders back to the reader.
    nonisolated static func sanitize(_ query: String) -> [String] {
        let scalars = query.unicodeScalars.prefix(maxQueryLength * 4)

        let cleaned = String(String.UnicodeScalarView(scalars.filter { scalar in
            // Cc control, Cf format (zero-width, bidi), Cs surrogate, Co private
            !(CharacterSet.controlCharacters.contains(scalar)
              || CharacterSet.illegalCharacters.contains(scalar)
              || (0x200B ... 0x200F).contains(scalar.value)     // zero-width, LRM/RLM
              || (0x202A ... 0x202E).contains(scalar.value)     // bidi embedding/override
              || (0x2066 ... 0x2069).contains(scalar.value)     // bidi isolates
              || scalar.value == 0xFEFF)                        // BOM
        }))

        var truncated = cleaned
        if truncated.count > maxQueryLength {
            truncated = String(truncated.prefix(maxQueryLength))
        }

        let words: [String] = truncated
            .components(separatedBy: .whitespacesAndNewlines)
            // A quote would end the quoted term early and let the rest be read
            // as operators, so it is removed rather than escaped.
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .filter { !$0.isEmpty }

        return Array(words.prefix(maxTerms))
    }

    /// Full-text search across every column the reader can see.
    ///
    /// Values are bound, never interpolated, so no input can alter the SQL. The
    /// FTS5 match expression is built from `sanitize`, which quotes every term.
    func search(_ query: String, limit: Int = 80) throws -> [SearchHit] {
        let terms = Self.sanitize(query)
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
                .compactMap { row in
                    // A row that will not decode is skipped, never fatal: search
                    // must degrade to fewer results rather than crash.
                    guard let verse = try? Verse(row: row) else { return nil }
                    return SearchHit(verse: verse, snippet: row["snippet"] ?? "")
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
