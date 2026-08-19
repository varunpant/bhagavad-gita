//
//  SharedProgress.swift
//  Gita
//

import Foundation
import OSLog

/// How far the reader has got, in the App Group, where a widget can reach it.
///
/// The same one-way arrangement as `SharedVerses`, and for the same reason: a
/// widget runs in its own process, cannot open `user.sqlite`, and cannot ask the
/// app for anything — when a timeline refreshes the app is usually not running.
/// So the app leaves a summary here whenever progress moves, and the widget
/// reads it.
///
/// Unlike the corpus this **is** perishable: it is a snapshot of a number that
/// changes. So it carries the day it was written, and the widget says "not read
/// today" from the day counts rather than assuming the file is current.
///
/// Tiny by construction — a few integers and at most thirty day counts — so the
/// app can afford to rewrite it on every verse read, and the widget can afford
/// to decode it on every timeline refresh.
nonisolated struct SharedProgress: Codable, Sendable {
    let versesRead: Int
    let totalVerses: Int
    let currentStreak: Int
    let longestStreak: Int
    /// `yyyy-MM-dd` → verses first read that day, for the last 30 days only.
    /// The whole history would grow without bound for a payload that is read to
    /// draw seven bars.
    let dayCounts: [String: Int]
    /// The reading language, so the widget's numerals and labels match the app
    /// the reader just came out of — see the language rules in `app/CLAUDE.md`.
    let isDevanagari: Bool
    /// `Theme` raw value, or `system` when the reader has not pinned one.
    let theme: String
    let updatedAt: Date

    static let systemTheme = "system"

    /// 0...1, and zero rather than a divide by nothing before the corpus loads.
    var completion: Double {
        guard totalVerses > 0 else { return 0 }
        return Double(versesRead) / Double(totalVerses)
    }

    // MARK: - Days

    /// `yyyy-MM-dd` in the reader's own timezone, on the Gregorian calendar with
    /// a POSIX locale.
    ///
    /// The same shape `Streak` stores, deliberately duplicated rather than
    /// shared: `Streak` is app-side, and the widget must be able to name today
    /// without compiling any of it. `SharedProgressTests` pins the two together
    /// so the copy cannot drift.
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func day(for date: Date) -> String { dayFormatter.string(from: date) }

    func count(on date: Date) -> Int { dayCounts[Self.day(for: date)] ?? 0 }

    /// The last `days` days, oldest first, including today and including the
    /// zeroes. A bar chart that skipped empty days would quietly redraw its own
    /// x-axis every time someone missed one.
    func recentDays(_ days: Int = 7, ending date: Date = Date()) -> [(date: Date, count: Int)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.dayFormatter.timeZone
        let today = calendar.startOfDay(for: date)

        return (0 ..< days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            return (day, count(on: day))
        }
    }

    /// Nothing read yet, and nothing shared yet, are different states — the
    /// widget says "open Gita once" for the second and "nothing today" for the
    /// first, so this exists to be shown, not to stand in for absence.
    static let empty = SharedProgress(
        versesRead: 0, totalVerses: 0, currentStreak: 0, longestStreak: 0,
        dayCounts: [:], isDevanagari: true, theme: systemTheme, updatedAt: .distantPast
    )
}

/// Where the file lives, and the two halves of using it.
nonisolated enum SharedProgressStore {
    private static let filename = "widget-progress.json"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "SharedProgress"
    )

    /// Nil on macOS, where there is nothing to share with.
    ///
    /// The widget extension is iOS-only, and asking for the group container on a
    /// Mac makes the system ask the reader whether "Gita.app would like to
    /// access data from other apps" — a question with no purpose here, and one
    /// that stops a test run dead until somebody clicks it.
    static var fileURL: URL? {
        #if os(iOS)
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedVerses.appGroup)?
            .appendingPathComponent(filename)
        #else
        nil
        #endif
    }

    // MARK: - Read, by the widget

    static func read() -> SharedProgress? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(SharedProgress.self, from: data)
    }

    // MARK: - Written, by the app

    /// Returns whether anything was written. A no-op when the payload is
    /// unchanged, so the caller may write on every verse read without churning
    /// the file — or, more to the point, without asking WidgetKit to redraw
    /// something identical.
    @discardableResult
    static func write(_ progress: SharedProgress) -> Bool {
        guard let fileURL else {
            logger.notice("No App Group container; widgets will show no progress")
            return false
        }
        if let existing = read(), existing.isEquivalent(to: progress) { return false }

        do {
            try JSONEncoder().encode(progress).write(to: fileURL, options: .atomic)
            return true
        } catch {
            logger.error("Could not share progress: \(error.localizedDescription)")
            return false
        }
    }
}

nonisolated extension SharedProgress {
    /// Equal in everything a widget draws. `updatedAt` is excluded on purpose:
    /// comparing it would make every write differ from the last, which is the
    /// whole thing `write` is trying to avoid.
    func isEquivalent(to other: SharedProgress) -> Bool {
        versesRead == other.versesRead
            && totalVerses == other.totalVerses
            && currentStreak == other.currentStreak
            && longestStreak == other.longestStreak
            && dayCounts == other.dayCounts
            && isDevanagari == other.isDevanagari
            && theme == other.theme
    }
}
