//
//  SharedVerses.swift
//  Gita
//

import Foundation
import OSLog

/// The little a widget needs from a verse.
///
/// Deliberately not `Verse`: the widget never shows meanings or word glosses,
/// and carrying them would quadruple a file that has to be decoded inside a
/// widget's very small memory budget. It carried a transliteration and a Hindi
/// translation that nothing read, for the same reason — now gone.
nonisolated struct WidgetVerse: Codable, Sendable {
    let chapter: Int
    let sutra: Int
    let sanskrit: String
    let english: String?

    var reference: String { "\(chapter).\(sutra)" }
}

/// The corpus, in the App Group, where a widget can reach it.
///
/// A widget runs in its own process and cannot read the app's bundle, and there
/// is no way for it to ask the app for anything — when a timeline refreshes the
/// app is usually not running at all. So the app leaves the text somewhere
/// shared, once, and the widget reads it from there forever.
///
/// The whole corpus rather than just today's verse: `DailyVerse` is a pure
/// function of the date, so with the text in hand a widget can work out any
/// day's verse by itself and can never go stale, however long since the app was
/// last opened.
nonisolated enum SharedVerses {
    struct Payload: Codable, Sendable {
        let contentVersion: String
        let verses: [WidgetVerse]
    }

    static let appGroup = "group.com.varunpant.Gita"
    private static let filename = "widget-verses.json"

    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "SharedVerses"
    )

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(filename)
    }

    // MARK: - Read by the widget

    static func read() -> Payload? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// The verse for a given day, or nil when the app has never been opened and
    /// there is nothing shared yet.
    ///
    /// Decodes the whole corpus, so a caller wanting several days should
    /// `read()` once and use `DailyVerse.index(for:count:calendar:)` itself —
    /// which is what the timeline does.
    static func verse(for date: Date, calendar: Calendar = .current) -> WidgetVerse? {
        guard let verses = read()?.verses, !verses.isEmpty else { return nil }
        return verses[DailyVerse.index(for: date, count: verses.count, calendar: calendar)]
    }

    // MARK: - Export bookkeeping

    /// What was last exported, kept beside the file so the app can tell whether
    /// a re-export is needed without decoding 680 KB of JSON to read one string.
    static var lastExported: (version: String, count: Int)? {
        get {
            guard let defaults = UserDefaults(suiteName: appGroup),
                  let version = defaults.string(forKey: "widgetVersesVersion") else { return nil }
            return (version, defaults.integer(forKey: "widgetVersesCount"))
        }
        set {
            guard let defaults = UserDefaults(suiteName: appGroup) else { return }
            defaults.set(newValue?.version, forKey: "widgetVersesVersion")
            defaults.set(newValue?.count ?? 0, forKey: "widgetVersesCount")
        }
    }
}
