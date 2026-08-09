//
//  SearchSafetyTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

/// The search box is the only place arbitrary user text reaches SQL. These
/// assert it cannot break the query, the database, or the app's responsiveness.
@Suite("Search input safety")
struct SearchSafetyTests {

    private func database() throws -> ContentDatabase { try ContentDatabase() }

    // MARK: - SQL and FTS5 injection

    /// Values are bound, never interpolated — but assert it rather than trust
    /// it, and assert the table is still there afterwards.
    @Test("SQL injection attempts return results or nothing, never damage", arguments: [
        "'; DROP TABLE verses; --",
        "\" OR 1=1 --",
        "'; DELETE FROM verses WHERE 1=1; --",
        "1' UNION SELECT * FROM sqlite_master --",
        "krishna'); DROP TABLE verses_fts; --",
        "\\'; ATTACH DATABASE '/tmp/evil.db' AS evil; --",
    ])
    func sqlInjectionIsInert(payload: String) throws {
        let db = try database()
        _ = try db.search(payload)                       // must not throw
        #expect(try db.allVerses().count == 701, "corpus damaged by: \(payload)")
    }

    /// FTS5's expression language is the likelier hazard: these are operators,
    /// and passing them through unquoted throws a syntax error.
    @Test("FTS5 operators are treated as literal text", arguments: [
        "\"", "\"\"\"", "*", "^", "-", ":", "(", ")", "()",
        "NEAR", "AND", "OR", "NOT", "krishna NEAR/5 arjuna",
        "column:value", "^start", "end*", "a AND (b OR c)", "*****",
    ])
    func ftsOperatorsAreLiteral(payload: String) throws {
        _ = try database().search(payload)               // must not throw
    }

    // MARK: - Size

    @Test("A pasted wall of text is truncated, not executed")
    func hugeInputIsBounded() throws {
        let huge = String(repeating: "krishna ", count: 50_000)   // ~400 KB
        #expect(huge.count > 100_000)

        let terms = ContentDatabase.sanitize(huge)
        #expect(terms.count <= ContentDatabase.maxTerms)

        let clock = ContinuousClock()
        let elapsed = try clock.measure { _ = try database().search(huge) }
        #expect(elapsed < .seconds(1), "huge query took \(elapsed)")
    }

    /// Truncation counts scalars, not Characters: a few visible characters can
    /// carry thousands of combining marks.
    @Test("A combining-mark bomb cannot smuggle in unbounded input")
    func combiningMarkBomb() throws {
        let bomb = "a" + String(repeating: "\u{0301}", count: 100_000)
        #expect(bomb.count < 10, "visibly short by design")

        let clock = ContinuousClock()
        let elapsed = try clock.measure { _ = try database().search(bomb) }
        #expect(elapsed < .seconds(1), "combining marks took \(elapsed)")
    }

    @Test("Many distinct terms are capped rather than ANDed forever")
    func termCountIsCapped() {
        let many = (0 ..< 500).map { "term\($0)" }.joined(separator: " ")
        #expect(ContentDatabase.sanitize(many).count == ContentDatabase.maxTerms)
    }

    // MARK: - Unicode

    @Test("Invisible and directional characters are stripped", arguments: [
        "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}",           // zero-width, BOM
        "\u{202E}gnirts", "\u{202D}x", "\u{2066}y\u{2069}",       // bidi override / isolate
        "\u{0000}", "\u{001B}[31m", "\u{007F}",                   // NUL, escape, DEL
    ])
    func invisibleCharactersAreRemoved(payload: String) throws {
        let terms = ContentDatabase.sanitize(payload)
        for term in terms {
            for scalar in term.unicodeScalars {
                #expect(!CharacterSet.controlCharacters.contains(scalar),
                        "control character survived in \(payload.debugDescription)")
                #expect(scalar.value != 0x200B && scalar.value != 0xFEFF,
                        "zero-width character survived")
                #expect(!(0x202A ... 0x202E).contains(scalar.value), "bidi override survived")
            }
        }
        _ = try database().search(payload)               // must not throw
    }

    @Test("Text that is only invisible characters searches for nothing")
    func invisibleOnlyQueryIsEmpty() throws {
        #expect(ContentDatabase.sanitize("\u{200B}\u{200D}\u{FEFF}").isEmpty)
        #expect(try database().search("\u{200B}\u{200D}\u{FEFF}").isEmpty)
    }

    @Test("Emoji, mixed scripts and lone surrogates do not throw", arguments: [
        "🙏", "कृष्ण 🕉️ krishna", "\u{1F600}\u{1F3FB}", "אבג", "日本語",
        "\u{FFFD}", "a\u{0301}\u{0302}\u{0303}", "ﷺ",
    ])
    func exoticTextIsSafe(payload: String) throws {
        _ = try database().search(payload)
    }

    // MARK: - Behaviour is preserved

    @Test("Hardening did not break ordinary search")
    func realQueriesStillWork() throws {
        let db = try database()
        #expect(try !db.search("kurukshetra").isEmpty)
        #expect(try !db.search("कर्म").isEmpty)
        #expect(try !db.search("grief").isEmpty)
        #expect(try db.search("zzzzzznotaword").isEmpty)
    }

    @Test("Search stays fast on ordinary input")
    func searchIsFast() throws {
        let db = try database()
        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            for term in ["krishna", "karma", "grief", "कर्म", "yoga"] {
                _ = try db.search(term)
            }
        }
        #expect(elapsed < .milliseconds(500), "five searches took \(elapsed)")
    }
}
