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

    /// Version stamp written by `tools/build_db.py`.
    func contentVersion() throws -> String? {
        try queue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'content_version'")
        }
    }
}
