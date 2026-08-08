//
//  Verse.swift
//  Gita
//

import Foundation
import GRDB

/// One verse of the Gita, as stored in the bundled read-only `gita.sqlite`.
///
/// v1 of the database carries the Sanskrit mula shloka only; the Hindi and
/// English blocks described in specs.md section 5 are not compiled in yet.
struct Verse: Identifiable, Hashable, Codable, Sendable, FetchableRecord, TableRecord {
    static let databaseTableName = "verses"

    /// Global running position, 1...701. Matches `counter` in srimad.csv.
    let id: Int
    let chapter: Int
    /// Verse number within its chapter.
    let sutra: Int
    /// Mula shloka in Devanagari.
    let sanskrit: String

    /// Traditional reference, e.g. "2.47".
    var reference: String { "\(chapter).\(sutra)" }
}

extension Verse {
    /// The shloka broken into display lines.
    ///
    /// Only 11 of the 701 rows in srimad.csv actually contain newlines; the rest
    /// are a single run of text in which the danda (।) is the only line break
    /// available. So: honour real newlines where they exist, and otherwise break
    /// on the danda — keeping the trailing `।।chapter.verse।।` marker attached to
    /// the final line, where it belongs.
    var lines: [String] {
        let text = sanskrit.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.contains("\n") {
            return text
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        var body = text
        var marker = ""
        if let range = body.range(of: "।।[0-9]+\\.[0-9]+।।$", options: .regularExpression) {
            marker = String(body[range])
            body = String(body[body.startIndex ..< range.lowerBound])
        }

        var result = body
            .components(separatedBy: "।")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0 + "।" }

        if !marker.isEmpty {
            if result.isEmpty {
                result = [marker]
            } else {
                result[result.count - 1] = String(result[result.count - 1].dropLast()) + marker
            }
        }
        return result
    }
}
