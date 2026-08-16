//
//  Chapter.swift
//  Gita
//

import Foundation
import GRDB

/// One of the eighteen chapters, named as the tradition names them.
///
/// Comes from `data/chapters.toml` — the same file the website reads — compiled
/// into the bundled database by `tools/build_db.py`.
nonisolated struct Chapter: Identifiable, Hashable, Codable, Sendable, FetchableRecord, TableRecord {
    static let databaseTableName = "chapters"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    /// 1...18.
    let id: Int
    /// Sanskrit name, e.g. अर्जुनविषादयोग.
    let nameSa: String
    /// English name, e.g. "The Despondency of Arjuna".
    let nameEn: String
    let verseCount: Int

    /// The chapter number in Devanagari numerals — used instead of the word
    /// "Chapter" in the contents list.
    var devanagariNumber: String { id.devanagariDigits }
}

nonisolated extension Int {
    /// The number written in Devanagari digits: ०१२३४५६७८९.
    ///
    /// Reading "47 श्लोक" in a Devanagari list is the same jar as an English
    /// subtitle under a Sanskrit name — the script should hold all the way
    /// through, numerals included.
    var devanagariDigits: String {
        String(String(self).map { character in
            guard let value = character.wholeNumberValue, (0 ... 9).contains(value) else {
                return character
            }
            return Character(UnicodeScalar(0x0966 + value)!)
        })
    }
}

/// A verse matched by search, with the passage that matched.
nonisolated struct SearchHit: Identifiable, Hashable, Sendable {
    let verse: Verse
    /// Snippet of the matching column, with the matched terms marked.
    let snippet: String

    var id: Int { verse.id }
}
