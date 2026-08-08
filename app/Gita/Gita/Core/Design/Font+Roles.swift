//
//  Font+Roles.swift
//  Gita
//

import SwiftUI

/// Fonts are named by **role**, never by face or by a bare point size.
///
/// Two rules hold throughout:
///
/// 1. Every role is built with `relativeTo:` so Dynamic Type — and the in-app
///    text-size setting, which rides on it — scales the whole page in
///    proportion. `.system(size:)` and bare `.custom(_:size:)` opt out entirely.
/// 2. A role is the **same point size in both scripts**. The shloka is 27pt
///    whether it is Devanagari or IAST, a gloss is 16pt either way. Only the
///    face changes with the script, never the size.
extension Font {
    // Devanagari. Kohinoor ships with both iOS and macOS; if it is ever absent
    // SwiftUI falls back to the system Devanagari face rather than failing.
    private static let devanagari = "KohinoorDevanagari-Light"
    private static let devanagariMedium = "KohinoorDevanagari-Medium"
    // Latin serif, present on both platforms, so IAST can be sized to match.
    private static let latin = "Georgia"

    // One size per role, shared by both scripts.
    private static let shlokaSize: CGFloat = 27
    private static let wordSize: CGFloat = 17
    private static let glossSize: CGFloat = 16
    private static let proseSize: CGFloat = 17

    /// The mula shloka — the largest, quietest thing on screen.
    static var shloka: Font {
        .custom(devanagari, size: shlokaSize, relativeTo: .title2)
    }

    /// The same shloka in IAST, at the same size.
    static var shlokaLatin: Font {
        .custom(latin, size: shlokaSize, relativeTo: .title2)
    }

    /// Chapter and verse reference, e.g. "2.47".
    static var verseReference: Font {
        .custom(devanagariMedium, size: 15, relativeTo: .subheadline)
    }

    /// A single word in the word-by-word list, and its gloss beside it.
    static var wordDevanagari: Font {
        .custom(devanagariMedium, size: wordSize, relativeTo: .body)
    }

    static var wordLatin: Font {
        .custom(latin, size: wordSize, relativeTo: .body).weight(.medium)
    }

    static var glossDevanagari: Font {
        .custom(devanagari, size: glossSize, relativeTo: .body)
    }

    static var glossLatin: Font {
        .custom(latin, size: glossSize, relativeTo: .body)
    }

    /// Prose — translations and explanations.
    static var proseDevanagari: Font {
        .custom(devanagari, size: proseSize, relativeTo: .body)
    }

    static var proseLatin: Font {
        .custom(latin, size: proseSize, relativeTo: .body)
    }

    /// Tracked labels and captions.
    static var label: Font {
        .system(.caption, design: .serif).weight(.medium)
    }
}
