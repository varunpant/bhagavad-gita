//
//  Verse+Sharing.swift
//  Gita
//

import Foundation

nonisolated extension Verse {

    /// The verse on bhagwadgita.info, matching the Hugo site's URL shape
    /// (`content/chapter-N/sutra-M.md` publishes to `/chapter-N/sutra-M/`).
    ///
    /// A web link rather than the `gita://verse/2/47` deep link: what gets
    /// shared usually lands with someone who does not have the app, and a
    /// custom scheme opens nothing for them. The site carries the same text and
    /// its own share card, so the link previews properly wherever it is pasted.
    var shareURL: URL {
        URL(string: "https://bhagwadgita.info/chapter-\(chapter)/sutra-\(sutra)/")!
    }

    func shareTitle(for language: ReadingLanguage) -> String {
        language == .sanskrit
            ? "श्रीमद्भगवद्गीता \(chapter.devanagariDigits).\(sutra.devanagariDigits)"
            : "Bhagavad Gita \(chapter).\(sutra)"
    }

    /// The verse itself, then its translation. Deliberately without the link —
    /// `ShareLink` carries the URL as the item, and repeating it in the message
    /// puts it twice into anything that pastes both.
    func shareText(for language: ReadingLanguage) -> String {
        var parts = [displayLines(for: language).joined(separator: "\n")]
        if let translation = translation(for: language), !translation.isEmpty {
            parts.append(translation)
        }
        parts.append(shareTitle(for: language))
        return parts.joined(separator: "\n\n")
    }
}
