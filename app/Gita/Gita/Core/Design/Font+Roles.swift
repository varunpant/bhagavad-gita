//
//  Font+Roles.swift
//  Gita
//

import SwiftUI

/// Fonts are named by **role**, never by face or by a fixed point size.
///
/// Every role is built with `relativeTo:` so Dynamic Type still scales the
/// bundled Devanagari and serif faces (specs.md section 14). `.system(size:)`
/// and bare `.custom(_:size:)` opt text out of Dynamic Type entirely — don't.
extension Font {
    /// Devanagari face. Kohinoor ships with both iOS and macOS; if it is ever
    /// absent SwiftUI falls back to the system Devanagari face rather than
    /// failing, so this is safe before a font is bundled.
    private static let devanagari = "KohinoorDevanagari-Light"
    private static let devanagariMedium = "KohinoorDevanagari-Medium"

    /// The mula shloka — the largest, quietest thing on screen.
    static var shloka: Font {
        .custom(devanagari, size: 27, relativeTo: .title2)
    }

    /// The shloka in IAST — a serif, so the transliteration reads as scripture
    /// rather than as UI text.
    static var shlokaLatin: Font {
        .system(.title3, design: .serif)
    }

    /// Chapter and verse reference, e.g. "2.47".
    static var verseReference: Font {
        .custom(devanagariMedium, size: 15, relativeTo: .subheadline)
    }

    /// A single word in the word-by-word list, and its gloss beside it.
    static var wordDevanagari: Font {
        .custom(devanagariMedium, size: 17, relativeTo: .body)
    }

    static var wordLatin: Font {
        .system(.body, design: .serif).weight(.medium)
    }

    static var glossDevanagari: Font {
        .custom(devanagari, size: 16, relativeTo: .body)
    }

    static var glossLatin: Font {
        .system(.body, design: .serif)
    }

    /// Tracked, small-caps-ish labels and captions.
    static var label: Font {
        .system(.caption, design: .serif).weight(.medium)
    }
}
