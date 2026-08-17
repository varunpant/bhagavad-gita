//
//  ProgressWidget.swift
//  GitaWidget
//

import SwiftUI
import WidgetKit

/// How far through the Gita the reader has got, at three sizes.
///
///   * small — the ring, with the count in the middle
///   * medium — today against everything read so far
///   * large — the last seven days as a chart, over the same summary
///
/// Reads the summary the app leaves in the App Group. It never asks the app for
/// anything, because it cannot: when a timeline refreshes the app is usually not
/// running. See `SharedProgress`.
struct ProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReadingProgress", provider: ProgressProvider()) { entry in
            ProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Reading Progress")
        .description("How far through the Gita you have read.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular])
    }
}

struct ProgressEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has been opened once and written the file.
    let progress: SharedProgress?
}

struct ProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: Date(), progress: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> Void) {
        // The gallery has no reader and no history, so show the preview rather
        // than an empty ring — a widget that looks broken in the picker does not
        // get picked.
        let progress = context.isPreview ? .preview : SharedProgressStore.read()
        completion(ProgressEntry(date: Date(), progress: progress))
    }

    /// One entry, refreshed at midnight.
    ///
    /// Progress only moves when the reader reads, and the app pushes a reload
    /// the moment it does — so there is nothing to schedule ahead. The one thing
    /// that changes without the app is the date: at midnight "today" becomes
    /// yesterday and the chart has to shift a column.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> Void) {
        let progress = SharedProgressStore.read()
        let entry = ProgressEntry(date: Date(), progress: progress)

        let midnight = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)

        // Nothing shared yet: the app has never been opened. Ask again within
        // the hour rather than at midnight, so the widget fills itself soon
        // after the first launch.
        let next = progress == nil ? Date().addingTimeInterval(1800) : midnight
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

extension SharedProgress {
    /// For the widget gallery and for previews. Plausible rather than perfect:
    /// a half-finished book with an uneven week behind it.
    static var preview: SharedProgress {
        var counts: [String: Int] = [:]
        for (offset, count) in [9, 14, 0, 22, 11, 26, 7].enumerated() {
            guard let day = Calendar.current.date(byAdding: .day, value: -6 + offset, to: Date())
            else { continue }
            counts[SharedProgress.day(for: day)] = count
        }
        return SharedProgress(
            versesRead: 327, totalVerses: 701, currentStreak: 6, longestStreak: 21,
            dayCounts: counts, isDevanagari: false, theme: SharedProgress.systemTheme,
            updatedAt: Date()
        )
    }
}
