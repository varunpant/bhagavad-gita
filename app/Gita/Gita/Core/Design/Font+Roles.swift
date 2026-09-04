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
    // Both faces are **bundled**, not system, and registered at launch by
    // `Fonts.register()`. Neither Inter nor Noto Sans Devanagari ships with
    // iOS or macOS, so a process that has not registered them draws in the
    // system face instead — silently, which is why registration happens before
    // the first view rather than lazily.
    //
    // Named by family, with the weight applied as a `.weight()` below. These
    // are variable fonts, whose named instances arrive with PostScript names
    // like `Inter-Regular_SemiBold`; asking for the family and a weight lets
    // CoreText pick the instance and keeps the roles legible.
    fileprivate static let devanagari = Fonts.devanagari
    fileprivate static let latin = Fonts.latin

    // The two weights the reading surface uses, as roles rather than numbers.
    // Devanagari is set a step lighter than its Latin counterpart at the same
    // size — Noto's Regular against Inter's is visibly heavier, because the
    // matras put more ink on the same line.
    fileprivate static let devanagariBody: Font.Weight = .light
    fileprivate static let devanagariEmphasis: Font.Weight = .medium

    // One size per role, shared by both scripts.
    private static let shlokaSize: CGFloat = 27
    private static let wordSize: CGFloat = 17
    private static let glossSize: CGFloat = 16
    private static let proseSize: CGFloat = 17

    /// The mula shloka — the largest, quietest thing on screen.
    static var shloka: Font {
        .custom(devanagari, size: shlokaSize, relativeTo: .title2)
            .weight(devanagariBody)
    }

    /// The same shloka in IAST, at the same size.
    static var shlokaLatin: Font {
        .custom(latin, size: shlokaSize, relativeTo: .title2)
    }

    /// Chapter and verse reference, e.g. "2.47".
    static var verseReference: Font {
        .custom(devanagari, size: 15, relativeTo: .subheadline)
            .weight(devanagariEmphasis)
    }

    /// A single word in the word-by-word list, and its gloss beside it.
    static var wordDevanagari: Font {
        .custom(devanagari, size: wordSize, relativeTo: .body)
            .weight(devanagariEmphasis)
    }

    static var wordLatin: Font {
        .custom(latin, size: wordSize, relativeTo: .body).weight(.medium)
    }

    static var glossDevanagari: Font {
        .custom(devanagari, size: glossSize, relativeTo: .body)
            .weight(devanagariBody)
    }

    static var glossLatin: Font {
        .custom(latin, size: glossSize, relativeTo: .body)
    }

    /// Prose — translations and explanations.
    static var proseDevanagari: Font {
        .custom(devanagari, size: proseSize, relativeTo: .body)
            .weight(devanagariBody)
    }

    static var proseLatin: Font {
        .custom(latin, size: proseSize, relativeTo: .body)
    }

    /// Tracked labels and captions.
    ///
    /// This was the one role that named no face at all — `.system(design: .serif)`,
    /// which resolved to New York beside Georgia. With the Latin side set in
    /// Inter it has to be Inter too, or every caption in the app is in a
    /// different family from the sentence above it.
    static var label: Font {
        .custom(latin, size: 12, relativeTo: .caption).weight(.medium)
    }

    /// The Devanagari counterpart to `.label`, and the reason it exists.
    ///
    /// Captions used to be written `isDevanagari ? .glossDevanagari : .label` —
    /// a 16pt body-scaled face against a 12pt caption-scaled one. The two look
    /// close enough at Large and come apart badly above it, because `.body` and
    /// `.caption` grow at different rates: switching language on a panel at an
    /// accessibility text size relaid the whole thing.
    ///
    /// 13pt against the label's 12: Devanagari carries matras above and below
    /// the line, so at an equal point size it reads a shade small beside a
    /// Latin serif.
    static var labelDevanagari: Font {
        .custom(devanagari, size: 13, relativeTo: .caption)
            .weight(devanagariEmphasis)
    }

    /// A face at an explicit size, for the share card — which is rendered at
    /// fixed pixel dimensions and so cannot ride on Dynamic Type like the
    /// reading roles above. It still picks its face here rather than naming
    /// one, so the card cannot drift from the app's typography.
    static func card(devanagari: Bool, size: CGFloat, medium: Bool = false) -> Font {
        let face = devanagari ? Self.devanagari : latin
        let weight: Font.Weight = medium
            ? (devanagari ? devanagariEmphasis : .medium)
            : (devanagari ? devanagariBody : .regular)
        return .custom(face, fixedSize: size).weight(weight)
    }
}
