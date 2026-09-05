//
//  StreakTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

/// Streaks are date arithmetic with awkward edges. `Streak` takes "today" as an
/// argument precisely so those edges can be written down here rather than
/// reproduced by moving a device's clock.
struct StreakTests {

    // MARK: - Current

    @Test func noDaysMeansNoStreak() {
        #expect(Streak.current(from: [], today: "2026-08-16") == 0)
    }

    @Test func readingTodayOnlyIsAStreakOfOne() {
        #expect(Streak.current(from: ["2026-08-16"], today: "2026-08-16") == 1)
    }

    @Test func consecutiveDaysEndingTodayCountTogether() {
        let days = ["2026-08-14", "2026-08-15", "2026-08-16"]
        #expect(Streak.current(from: days, today: "2026-08-16") == 3)
    }

    /// The one real decision in `Streak`: the day's first verse has not been
    /// read yet, and the streak must not read as broken until a whole day has
    /// passed. Someone checking their streak over breakfast should see it.
    @Test func yesterdayKeepsTheStreakAliveThroughToday() {
        let days = ["2026-08-14", "2026-08-15"]
        #expect(Streak.current(from: days, today: "2026-08-16") == 2)
    }

    @Test func aFullMissedDayBreaksIt() {
        let days = ["2026-08-13", "2026-08-14"]
        #expect(Streak.current(from: days, today: "2026-08-16") == 0)
    }

    /// Only the run touching today counts — an older, longer run does not
    /// resurrect a broken streak.
    @Test func onlyTheRunEndingNowCounts() {
        let days = ["2026-07-01", "2026-07-02", "2026-07-03", "2026-07-04", "2026-08-16"]
        #expect(Streak.current(from: days, today: "2026-08-16") == 1)
    }

    @Test func runsAcrossAMonthBoundary() {
        let days = ["2026-07-30", "2026-07-31", "2026-08-01"]
        #expect(Streak.current(from: days, today: "2026-08-01") == 3)
    }

    /// 2028 is a leap year, so the 29th is a real day and the run is unbroken.
    @Test func runsAcrossLeapDay() {
        let days = ["2028-02-28", "2028-02-29", "2028-03-01"]
        #expect(Streak.current(from: days, today: "2028-03-01") == 3)
    }

    @Test func duplicateDaysDoNotInflateIt() {
        let days = ["2026-08-15", "2026-08-15", "2026-08-16"]
        #expect(Streak.current(from: days, today: "2026-08-16") == 2)
    }

    @Test func unsortedInputIsHandled() {
        let days = ["2026-08-16", "2026-08-14", "2026-08-15"]
        #expect(Streak.current(from: days, today: "2026-08-16") == 3)
    }

    // MARK: - Longest

    @Test func longestOfNothingIsZero() {
        #expect(Streak.longest(from: []) == 0)
    }

    @Test func longestFindsTheBestRunAnywhere() {
        let days = [
            "2026-07-01", "2026-07-02", "2026-07-03", "2026-07-04",   // 4
            "2026-08-15", "2026-08-16",                               // 2
        ]
        #expect(Streak.longest(from: days) == 4)
    }

    /// The longest is not necessarily the current one, which is the whole
    /// reason both exist.
    @Test func longestCanExceedCurrent() {
        let days = ["2026-07-01", "2026-07-02", "2026-07-03", "2026-08-16"]
        #expect(Streak.longest(from: days) == 3)
        #expect(Streak.current(from: days, today: "2026-08-16") == 1)
    }

    @Test func longestOfASingleDayIsOne() {
        #expect(Streak.longest(from: ["2026-08-16"]) == 1)
    }

    // MARK: - Day keys

    @Test func dayKeysAreStableAcrossTheDay() {
        let morning = Date(timeIntervalSince1970: 1_786_000_000)
        let later = morning.addingTimeInterval(3_600)
        // Same hour band either side of the addition, so this is a formatting
        // check rather than a timezone one.
        #expect(Streak.day(for: morning).count == 10)
        #expect(Streak.day(for: later).count == 10)
    }
}

/// The civil-date arithmetic that replaced `DateFormatter` in the streak loops.
///
/// Worth pinning against the thing it replaced rather than against hand-written
/// expectations: the point of the change is that it computes *the same days*
/// more cheaply, and a leap-year or century-boundary slip in Hinnant's
/// algorithm would show up as a streak that is one short — a number nobody can
/// check by looking at it.
@Suite("Day numbers")
struct DayNumberTests {

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Every day across sixteen years, including four leap years and the
    /// 2100-style century rule, agrees with what `DateFormatter` parses.
    @Test("Day numbers advance exactly one per calendar day, for years at a time")
    func agreesWithTheFormatterAcrossYears() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.formatter.timeZone

        let start = try #require(Self.formatter.date(from: "2016-01-01"))
        var date = start
        var previous: Int?
        var checked = 0

        while checked < 16 * 365 {
            let key = Self.formatter.string(from: date)
            let number = try #require(Streak.dayNumber(key), "\(key) did not parse")
            if let previous {
                #expect(number == previous + 1,
                        "\(key) is not one day after the day before it")
            }
            previous = number
            date = try #require(calendar.date(byAdding: .day, value: 1, to: date))
            checked += 1
        }
    }

    /// The epoch and the leap days, stated outright.
    @Test("Known days have known numbers", arguments: [
        ("1970-01-01", 0), ("1970-01-02", 1), ("1969-12-31", -1),
        ("2000-02-29", 11016),          // a leap year: divisible by 400
        ("2024-02-29", 19782),
    ])
    func knownDays(key: String, number: Int) {
        #expect(Streak.dayNumber(key) == number)
    }

    /// A date that does not exist is refused, not rounded into the next month —
    /// which is what `DateFormatter.date(from:)` did, and what the round-trip
    /// check inside `dayNumber` is there to preserve.
    @Test("Impossible and malformed days are refused", arguments: [
        "2025-02-30", "2023-02-29", "2025-13-01", "2025-00-10", "2025-01-32",
        "2025-1-01", "25-01-01", "2025-01", "", "not-a-date", "2025/01/01",
    ])
    func refusesNonsense(key: String) {
        #expect(Streak.dayNumber(key) == nil, "\(key) should not parse")
    }

    /// 2100 is not a leap year, and an algorithm that only checks divisibility
    /// by four says it is. One day out, seventy-five years from now.
    @Test("The century rule holds")
    func centuryRule() throws {
        let feb28 = try #require(Streak.dayNumber("2100-02-28"))
        let mar1 = try #require(Streak.dayNumber("2100-03-01"))
        #expect(mar1 == feb28 + 1, "2100-02-29 was treated as a real day")
        #expect(Streak.dayNumber("2100-02-29") == nil)
    }
}
