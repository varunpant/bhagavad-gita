//
//  Verse+Sharing.swift
//  Gita
//

import Foundation

nonisolated extension Verse {

    /// The app link for this verse — the same `gita://verse/<chapter>/<sutra>`
    /// scheme the widgets already deep-link with, so a shared verse opens
    /// straight to it for anyone with the app.
    var shareURL: URL {
        URL(string: "gita://verse/\(chapter)/\(sutra)")!
    }

    func shareTitle(for language: ReadingLanguage) -> String {
        language.isDevanagari
            ? "श्रीमद्भगवद्गीता \(chapter.devanagariDigits).\(sutra.devanagariDigits)"
            : "Bhagavad Gita \(chapter).\(sutra)"
    }

    /// The verse itself, then its translation, then the reference. `ShareLink`
    /// carries the URL as the item, so it is not repeated here — that would put
    /// it twice into anything that pastes both.
    func shareText(for language: ReadingLanguage) -> String {
        var parts = [displayLines(for: language).joined(separator: "\n")]
        if let translation = translation(for: language), !translation.isEmpty {
            parts.append(translation)
        }
        parts.append(shareTitle(for: language))
        return parts.joined(separator: "\n\n")
    }
}
