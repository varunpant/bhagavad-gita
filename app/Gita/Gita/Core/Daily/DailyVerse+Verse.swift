//
//  DailyVerse+Verse.swift
//  Gita
//

import Foundation

/// The `Verse` convenience, kept apart from `DailyVerse` itself so that the pure
/// day-to-index function can compile into the widget extension without dragging
/// in `Verse` and, through it, GRDB.
nonisolated extension DailyVerse {
    static func verse(for date: Date, in verses: [Verse], calendar: Calendar = .current) -> Verse? {
        guard !verses.isEmpty else { return nil }
        return verses[index(for: date, count: verses.count, calendar: calendar)]
    }
}
