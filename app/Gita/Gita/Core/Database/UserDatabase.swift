//
//  UserDatabase.swift
//  Gita
//

import Foundation
import GRDB
import OSLog

/// The user's own data — settings now, bookmarks and reading progress next.
///
/// Deliberately separate from the bundled content database (specs.md §4.2): a
/// new `gita.sqlite` ships with every app update, and it must never be able to
/// touch what the reader has saved.
///
/// `nonisolated` so writes happen off the main actor; GRDB serialises access.
nonisolated struct UserDatabase {
    private let queue: DatabaseQueue
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "UserDatabase"
    )

    /// Prefers the App Group container so widgets can read the same file. Falls
    /// back to Application Support when the entitlement is not present — which
    /// is the case until the App Group capability is added to the target.
    static func storeURL() throws -> URL {
        let manager = FileManager.default
        let group = "group.\(Bundle.main.bundleIdentifier ?? "com.varunpant.Gita")"

        if let container = manager.containerURL(forSecurityApplicationGroupIdentifier: group) {
            return container.appendingPathComponent("user.sqlite")
        }

        logger.notice("App Group unavailable; using Application Support")
        let support = try manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try manager.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("user.sqlite")
    }

    init(url: URL? = nil) throws {
        queue = try DatabaseQueue(path: (url ?? Self.storeURL()).path)
        try Self.migrator.migrate(queue)
    }

    /// Append-only forever: never edit a registered migration, only add another.
    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createSettings") { db in
            try db.create(table: "settings") { table in
                table.primaryKey("key", .text)
                table.column("value", .text).notNull()
            }
        }
        return migrator
    }

    func string(_ key: String) throws -> String? {
        try queue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = ?", arguments: [key])
        }
    }

    func set(_ value: String, for key: String) throws {
        try queue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
                arguments: [key, value]
            )
        }
    }

    func all() throws -> [String: String] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT key, value FROM settings")
                .reduce(into: [:]) { $0[$1["key"] as String] = $1["value"] as String }
        }
    }
}
