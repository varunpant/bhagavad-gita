//
//  ReadingLanguage.swift
//  Gita
//

import Foundation

/// Which rendering of the verse the reader is showing.
///
/// Mirrors RigVeda's `Language`: one switch flips both the scripture and the
/// word-by-word glosses together, rather than making them independent settings
/// nobody wants to manage separately.
enum ReadingLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Devanagari shloka, Hindi word meanings.
    case sanskrit
    /// IAST transliteration, English word meanings.
    case english

    var id: String { rawValue }

    /// The glyph on the toggle — "अ" or "A", the script each mode is written in.
    var icon: String {
        switch self {
        case .sanskrit: "अ"
        case .english: "A"
        }
    }

    var accessibilityName: String {
        switch self {
        case .sanskrit: "Sanskrit with Hindi meanings"
        case .english: "Transliteration with English meanings"
        }
    }

    var toggled: ReadingLanguage {
        self == .sanskrit ? .english : .sanskrit
    }

    /// Whether this mode is written in Devanagari.
    ///
    /// Views ask this constantly — it picks the string, the face and the
    /// numerals together (see the language rules in `app/CLAUDE.md`). Seven of
    /// them had defined their own `isDevanagari` before this existed.
    nonisolated var isDevanagari: Bool { self == .sanskrit }
}
