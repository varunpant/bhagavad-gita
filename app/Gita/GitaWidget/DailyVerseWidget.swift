//
//  DailyVerseWidget.swift
//  GitaWidget
//

import SwiftUI
import WidgetKit

/// A verse a day, on the home and lock screen.
///
/// The widget reads the corpus the app exported into the App Group and works out
/// the day itself with `DailyVerse`, so it never needs the app to be running and
/// never shows stale text.
struct DailyVerseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyVerse", provider: Provider()) { entry in
            DailyVerseView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Daily Verse")
        .description("A verse from the Bhagavad Gita each day.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let verse: WidgetVerse?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), verse: SharedVerses.verse(for: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), verse: SharedVerses.verse(for: Date())))
    }

    /// A week of entries in one go. Each day's verse is a pure function of its
    /// date, so they can all be computed now — the widget then needs no refresh
    /// at all for a week, rather than waking every midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let entries = (0 ..< 7).compactMap { offset -> Entry? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return Entry(date: day, verse: SharedVerses.verse(for: day, calendar: calendar))
        }

        // Nothing shared yet: the app has never been opened. Ask again in an
        // hour rather than in a week, so the widget fills itself soon after.
        let policy: TimelineReloadPolicy = entries.first?.verse == nil
            ? .after(Date().addingTimeInterval(3600))
            : .atEnd

        completion(Timeline(entries: entries, policy: policy))
    }
}
