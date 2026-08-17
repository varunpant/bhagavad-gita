//
//  SharedProgressTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

/// The summary the app leaves for the widget.
///
/// A widget cannot be asked what it is showing, and nobody notices a wrong
/// number on a home screen for weeks — so the arithmetic is tested here, where
/// it is a pure function of a struct.
struct SharedProgressTests {

    private func progress(
        read: Int = 0, total: Int = 701, streak: Int = 0, days: [String: Int] = [:]
    ) -> SharedProgress {
        SharedProgress(
            versesRead: read, totalVerses: total,
            currentStreak: streak, longestStreak: streak,
            dayCounts: days, isDevanagari: false,
            theme: SharedProgress.systemTheme, updatedAt: Date()
        )
    }

    // MARK: - Day keys

    /// The one that matters most. `SharedProgress` names days itself so the
    /// widget never has to compile `Streak`, and a copied format that drifts
    /// would silently zero the widget's chart while the app's streak carried on
    /// working — a bug with no symptom on the side that is being looked at.
    @Test func dayKeysMatchTheOnesTheAppStores() {
        var date = Date(timeIntervalSince1970: 0)
        for _ in 0 ..< 400 {
            #expect(SharedProgress.day(for: date) == Streak.day(for: date))
            date.addTimeInterval(60 * 60 * 24 + 3600)   // drift across DST too
        }
    }

    // MARK: - Completion

    @Test func completionIsTheReadFraction() {
        #expect(progress(read: 350, total: 700).completion == 0.5)
    }

    /// Before the corpus loads there is no denominator, and dividing by it
    /// would be a crash on a home screen.
    @Test func completionIsZeroWithoutACorpus() {
        #expect(progress(read: 12, total: 0).completion == 0)
    }

    // MARK: - Days

    @Test func todaysCountComesFromTheDayItWasRead() {
        let today = SharedProgress.day(for: Date())
        #expect(progress(days: [today: 9]).count(on: Date()) == 9)
    }

    /// Seven columns, always — including the days nothing was read on. Dropping
    /// the empties would let the chart quietly redraw its own axis.
    @Test func theWeekIncludesItsEmptyDays() {
        let today = SharedProgress.day(for: Date())
        let week = progress(days: [today: 4]).recentDays(7)

        #expect(week.count == 7)
        #expect(week.map(\.count).filter { $0 == 0 }.count == 6)
        #expect(week.last?.count == 4, "today should be the last column, not the first")
    }

    @Test func theWeekIsOldestFirst() {
        let dates = progress().recentDays(7).map(\.date)
        #expect(dates == dates.sorted())
    }

    // MARK: - Writing

    /// `write` skips an unchanged payload so a verse read does not ask WidgetKit
    /// to redraw something identical. Two payloads that differ only in when they
    /// were written are the same payload.
    @Test func aNewTimestampAloneIsNotAChange() {
        let first = progress(read: 10)
        let second = SharedProgress(
            versesRead: 10, totalVerses: 701, currentStreak: 0, longestStreak: 0,
            dayCounts: [:], isDevanagari: false, theme: SharedProgress.systemTheme,
            updatedAt: Date().addingTimeInterval(9_999)
        )
        #expect(first.isEquivalent(to: second))
    }

    /// The two that are not about progress at all, and are the reason the
    /// widget can follow the app's theme and script.
    @Test func aThemeOrScriptChangeCountsAsAChange() {
        let base = progress(read: 10)
        let sepia = SharedProgress(
            versesRead: 10, totalVerses: 701, currentStreak: 0, longestStreak: 0,
            dayCounts: [:], isDevanagari: false, theme: "sepia", updatedAt: Date()
        )
        let devanagari = SharedProgress(
            versesRead: 10, totalVerses: 701, currentStreak: 0, longestStreak: 0,
            dayCounts: [:], isDevanagari: true, theme: SharedProgress.systemTheme,
            updatedAt: Date()
        )
        #expect(!base.isEquivalent(to: sepia))
        #expect(!base.isEquivalent(to: devanagari))
    }

    // MARK: - Round trip

    /// It crosses a process boundary as JSON, so encoding is not an
    /// implementation detail.
    @Test func itSurvivesAJSONRoundTrip() throws {
        let today = SharedProgress.day(for: Date())
        let original = progress(read: 327, streak: 6, days: [today: 12])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedProgress.self, from: data)

        #expect(decoded.isEquivalent(to: original))
        #expect(decoded.recentDays(7).last?.count == 12)
    }
}
