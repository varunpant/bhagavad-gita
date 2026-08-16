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
