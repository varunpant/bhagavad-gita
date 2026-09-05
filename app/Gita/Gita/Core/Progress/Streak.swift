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

    static func day(for date: Date) -> String { dayFormatter.string(from: date) }

    // MARK: - Days as numbers

    /// A `yyyy-MM-dd` key as a count of days, so a run of them is arithmetic.
    ///
    /// The streak loops used to walk in `Date`s, which meant a `DateFormatter`
    /// call for every day examined: `longest` did three per reading day — parse
    /// the key, add a day, format it back — so a reader with a year of history
    /// paid about eleven hundred formatter calls, and `snapshot` recomputes on
    /// every read. Formatters are also locked internally, so those are not
    /// cheap microseconds.
    ///
    /// Nothing is lost by leaving `Date` behind. These keys are civil dates in
    /// a fixed Gregorian calendar, and the day after a civil date is a matter
    /// of counting, not of clocks: the daylight-saving trap the old comment
    /// warns about is real for `addingTimeInterval(-86_400)` on an instant, and
    /// cannot arise here, because there is no instant left to shift.
    static func dayNumber(_ day: String) -> Int? {
        let parts = day.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let dayOfMonth = Int(parts[2]),
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              (1 ... 12).contains(month), (1 ... 31).contains(dayOfMonth)
        else { return nil }

        let number = daysFromCivil(year: year, month: month, day: dayOfMonth)
        // Rejects the dates that look well-formed and do not exist — "2025-02-30"
        // — which `DateFormatter.date(from:)` also refused. Without the check
        // they would quietly become the first of March.
        guard civilFromDays(number) == (year, month, dayOfMonth) else { return nil }
        return number
    }

    /// Days from 1970-01-01, by Howard Hinnant's civil-date algorithm. Exact
    /// for every proleptic Gregorian date, with no table and no branch on leap
    /// years beyond the era arithmetic.
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = year - (month <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400                                  // [0, 399]
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// The inverse, used only to reject impossible dates.
    private static func civilFromDays(_ number: Int) -> (Int, Int, Int) {
        let z = number + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097                               // [0, 146096]
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let year = yearOfEra + era * 400
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp + (mp < 10 ? 3 : -9)
        return (year + (month <= 2 ? 1 : 0), month, day)
    }

    /// The run of consecutive days ending today — or ending yesterday, if
    /// nothing has been read yet today.
    ///
    /// That second clause is the only real decision in this file. Without it a
    /// streak reads as zero from midnight until the day's first verse, which is
    /// precisely when someone opens the app to check on it. Yesterday's reading
    /// keeps the streak alive for the whole of today; it breaks only once a
    /// full day has passed with nothing read.
    static func current(from days: some Sequence<String>, today: String) -> Int {
        // A day that cannot be parsed is dropped rather than counted, which is
        // what happened before: it could never equal a key this type produced.
        let set = Set(days.compactMap(dayNumber))
        guard !set.isEmpty, let todayNumber = dayNumber(today) else { return 0 }

        // Anchor on today if it counts, otherwise on yesterday. If neither has
        // been read the streak is over, whatever came before.
        var cursor: Int
        if set.contains(todayNumber) {
            cursor = todayNumber
        } else if set.contains(todayNumber - 1) {
            cursor = todayNumber - 1
        } else {
            return 0
        }

        var length = 0
        while set.contains(cursor) {
            length += 1
            cursor -= 1
        }
        return length
    }

    /// The longest run anywhere in the history, which is not necessarily the
    /// current one and is not necessarily the most recent.
    static func longest(from days: some Sequence<String>) -> Int {
        let sorted = Set(days.compactMap(dayNumber)).sorted()
        guard !sorted.isEmpty else { return 0 }

        var longest = 1
        var run = 1
        for (previous, day) in zip(sorted, sorted.dropFirst()) {
            run = day == previous + 1 ? run + 1 : 1
            longest = max(longest, run)
        }
        return longest
    }

}
