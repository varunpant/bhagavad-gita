//
//  Streak.swift
//  Gita
//

import Foundation

/// Consecutive days of reading, computed from the list of days on which at
/// least one verse was read.
///
/// Every function here is `nonisolated`, pure, and takes the current day as an
/// argument rather than reading the clock. That is the whole point: a streak is
/// nothing but date arithmetic with awkward edges, and awkward edges want unit
/// tests, not a running app and a device whose clock you cannot move.
nonisolated enum Streak {

    /// Days are stored — and compared — as `yyyy-MM-dd` in the reader's own
    /// calendar. A fixed `en_US_POSIX` locale and the Gregorian calendar so the
    /// stored key never shifts under a device set to, say, the Hindu calendar;
    /// the *timezone* stays local, which is what makes "today" mean today.
    nonisolated static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Built once. It was being constructed per day inside the streak loops —
    /// a hundred `Calendar` allocations to walk a hundred-day streak.
    private nonisolated static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = dayFormatter.timeZone
        return calendar
    }()

    static func day(for date: Date) -> String { dayFormatter.string(from: date) }

    /// The run of consecutive days ending today — or ending yesterday, if
    /// nothing has been read yet today.
    ///
    /// That second clause is the only real decision in this file. Without it a
    /// streak reads as zero from midnight until the day's first verse, which is
    /// precisely when someone opens the app to check on it. Yesterday's reading
    /// keeps the streak alive for the whole of today; it breaks only once a
    /// full day has passed with nothing read.
    static func current(from days: some Sequence<String>, today: String) -> Int {
        let set = Set(days)
        guard !set.isEmpty else { return 0 }

        // Anchor on today if it counts, otherwise on yesterday. If neither has
        // been read the streak is over, whatever came before.
        guard let todayDate = dayFormatter.date(from: today) else { return 0 }
        var cursor: Date
        if set.contains(today) {
            cursor = todayDate
        } else if let yesterday = previousDay(of: todayDate), set.contains(day(for: yesterday)) {
            cursor = yesterday
        } else {
            return 0
        }

        var length = 0
        while set.contains(day(for: cursor)) {
            length += 1
            guard let earlier = previousDay(of: cursor) else { break }
            cursor = earlier
        }
        return length
    }

    /// The longest run anywhere in the history, which is not necessarily the
    /// current one and is not necessarily the most recent.
    static func longest(from days: some Sequence<String>) -> Int {
        let sorted = Set(days).sorted()
        guard !sorted.isEmpty else { return 0 }

        var longest = 1
        var run = 1
        for (previous, day) in zip(sorted, sorted.dropFirst()) {
            if isDayAfter(day, previous) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }
        return longest
    }

    // MARK: - Date arithmetic

    /// Calendar arithmetic, not `addingTimeInterval(-86_400)`. A day is not
    /// always 86,400 seconds — daylight saving makes two of them a year 23 or
    /// 25 hours long, and subtracting a fixed interval across one of those
    /// lands on the wrong date and silently breaks the streak.
    private static func previousDay(of date: Date) -> Date? {
        calendar.date(byAdding: .day, value: -1, to: date)
    }

    private static func isDayAfter(_ day: String, _ previous: String) -> Bool {
        guard let previousDate = dayFormatter.date(from: previous),
              let nextDate = nextDay(of: previousDate) else { return false }
        return self.day(for: nextDate) == day
    }

    private static func nextDay(of date: Date) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: date)
    }
}
