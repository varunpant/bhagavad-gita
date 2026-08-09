//
//  DailyVerseTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

/// The daily verse must be a pure function of the date: the app, the
/// notification and the widget each compute it independently and must agree.
@Suite("Daily verse")
struct DailyVerseTests {

    private let calendar = Calendar(identifier: .gregorian)
    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test("The same day always gives the same verse")
    func deterministic() {
        let date = day(2026, 8, 9)
        let first = DailyVerse.index(for: date, count: 701, calendar: calendar)
        for _ in 0 ..< 50 {
            #expect(DailyVerse.index(for: date, count: 701, calendar: calendar) == first)
        }
    }

    @Test("Every moment within a day gives the same verse")
    func stableAcrossTheDay() {
        let midnight = calendar.startOfDay(for: day(2026, 8, 9))
        let expected = DailyVerse.index(for: midnight, count: 701, calendar: calendar)
        for hour in [0, 6, 12, 18, 23] {
            let moment = calendar.date(byAdding: .hour, value: hour, to: midnight)!
            #expect(DailyVerse.index(for: moment, count: 701, calendar: calendar) == expected)
        }
    }

    @Test("Consecutive days are not consecutive verses")
    func notSequential() {
        // A modulo scheme would walk 1.1, 1.2, 1.3 and never reach chapter 18.
        let indices = (0 ..< 10).map { offset -> Int in
            let date = calendar.date(byAdding: .day, value: offset, to: day(2026, 1, 1))!
            return DailyVerse.index(for: date, count: 701, calendar: calendar)
        }
        let steps = zip(indices, indices.dropFirst()).map { $1 - $0 }
        #expect(!steps.allSatisfy { $0 == 1 }, "walked the corpus in order: \(indices)")
    }

    /// The guarantee is per aligned cycle. A window that straddles a cycle
    /// boundary draws from two different permutations, so it can repeat one
    /// verse and miss another — that is the documented trade for holding no
    /// state, and 701 days is nearly two years away.
    @Test("An aligned cycle visits every verse exactly once")
    func coversTheCorpus() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!

        let count = 701
        let epoch = Date(timeIntervalSince1970: 0)      // day 0 — a cycle boundary
        let seen = (0 ..< count).map { offset in
            DailyVerse.index(for: utc.date(byAdding: .day, value: offset, to: epoch)!,
                             count: count, calendar: utc)
        }
        #expect(Set(seen).count == count, "\(count - Set(seen).count) verses missed in a cycle")
        #expect(seen.allSatisfy { (0 ..< count).contains($0) })
    }

    @Test("Indices stay in range for any corpus size", arguments: [1, 2, 7, 700, 701, 10_000])
    func alwaysInRange(count: Int) {
        for offset in 0 ..< 40 {
            let date = calendar.date(byAdding: .day, value: offset, to: day(2026, 3, 1))!
            let index = DailyVerse.index(for: date, count: count, calendar: calendar)
            #expect((0 ..< count).contains(index), "index \(index) out of range for count \(count)")
        }
    }

    @Test("An empty corpus yields no verse rather than crashing")
    func emptyCorpus() {
        #expect(DailyVerse.verse(for: Date(), in: [], calendar: calendar) == nil)
        #expect(DailyVerse.index(for: Date(), count: 0, calendar: calendar) == 0)
    }
}
