//
//  ProgressStoreTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

/// A `user.sqlite` in a temporary directory, so tests never touch the store the
/// app on this machine is actually using.
enum TempStore {
    static func url() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gita-tests-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
    }
}

/// The progress tables: recorded once, counted once, and reset without taking
/// anything else with them.
struct ProgressStoreTests {

    private func store() throws -> UserDatabase {
        try UserDatabase(url: TempStore.url())
    }

    @Test func aFreshStoreHasNoProgress() throws {
        let database = try store()
        #expect(try database.readVerseIDs().isEmpty)
        #expect(try database.readingDays().isEmpty)
        #expect(try database.unlockedBadgeIDs().isEmpty)
    }

    @Test func recordingAVerseMarksItRead() throws {
        let database = try store()
        let isFirst = try database.recordRead(47, on: "2026-08-16")

        #expect(isFirst)
        #expect(try database.readVerseIDs() == [47])
        #expect(try database.readingDays() == ["2026-08-16"])
    }

    /// The single most important property here: reading 2.47 again on a later
    /// day must not make it count twice. Every total in the app is built on
    /// this being true.
    @Test func recordingTheSameVerseTwiceCountsOnce() throws {
        let database = try store()
        #expect(try database.recordRead(47, on: "2026-08-16"))
        #expect(try database.recordRead(47, on: "2026-08-17") == false)

        #expect(try database.readVerseIDs() == [47])
        #expect(try database.readingDayCounts() == ["2026-08-16": 1])
    }

    /// A re-read does not create a day either — otherwise flicking through
    /// familiar ground would manufacture a streak out of nothing.
    @Test func aRereadDoesNotCreateAReadingDay() throws {
        let database = try store()
        try database.recordRead(47, on: "2026-08-16")
        try database.recordRead(47, on: "2026-08-20")

        #expect(try database.readingDays() == ["2026-08-16"])
    }

    @Test func versesReadPerDayAccumulate() throws {
        let database = try store()
        for verse in 1 ... 5 { try database.recordRead(verse, on: "2026-08-16") }
        for verse in 6 ... 8 { try database.recordRead(verse, on: "2026-08-17") }

        #expect(try database.readingDayCounts() == ["2026-08-16": 5, "2026-08-17": 3])
    }

    @Test func readingDaysComeBackInOrder() throws {
        let database = try store()
        try database.recordRead(3, on: "2026-08-17")
        try database.recordRead(1, on: "2026-08-15")
        try database.recordRead(2, on: "2026-08-16")

        #expect(try database.readingDays() == ["2026-08-15", "2026-08-16", "2026-08-17"])
    }

    // MARK: - Badges

    @Test func badgesUnlockOnceAndStay() throws {
        let database = try store()
        try database.unlockBadges(["first_step", "chapter_1"])
        try database.unlockBadges(["first_step"])

        #expect(try database.unlockedBadgeIDs() == ["first_step", "chapter_1"])
    }

    @Test func unlockingNothingIsHarmless() throws {
        let database = try store()
        try database.unlockBadges([String]())
        #expect(try database.unlockedBadgeIDs().isEmpty)
    }

    // MARK: - Reset

    @Test func resetErasesProgress() throws {
        let database = try store()
        try database.recordRead(1, on: "2026-08-16")
        try database.recordRead(2, on: "2026-08-16")
        try database.unlockBadges(["first_step"])

        try database.resetProgress()

        #expect(try database.readVerseIDs().isEmpty)
        #expect(try database.readingDays().isEmpty)
        #expect(try database.unlockedBadgeIDs().isEmpty)
    }

    /// The promise made to the reader in the confirmation dialog. People
    /// conflate bookmarks with progress, and losing forty kept verses to a
    /// "reset progress" tap would be unforgivable.
    @Test func resetLeavesBookmarksAndSettingsAlone() throws {
        let database = try store()
        try database.addBookmark(47)
        try database.set("sepia", for: "theme")
        try database.recordRead(1, on: "2026-08-16")

        try database.resetProgress()

        #expect(try database.bookmarkedVerseIDs() == [47])
        #expect(try database.string("theme") == "sepia")
        #expect(try database.readVerseIDs().isEmpty)
    }

    /// Reset is not a factory wipe: the tables survive so recording works
    /// immediately afterwards without reopening the database.
    @Test func progressCanBeRecordedAgainAfterAReset() throws {
        let database = try store()
        try database.recordRead(1, on: "2026-08-16")
        try database.resetProgress()

        #expect(try database.recordRead(1, on: "2026-08-17"))
        #expect(try database.readVerseIDs() == [1])
    }
}

/// The dwell policy — the judgement part of the tracker, separated from the
/// sleep so it can be tested at all.
struct ReadingPolicyTests {

    private func conditions(
        active: Bool = true, drawer: Bool = false, panel: Bool = false,
        searching: Bool = false, read: Bool = false
    ) -> ReadingPolicy.Conditions {
        ReadingPolicy.Conditions(
            isActive: active, drawerIsOpen: drawer, panelIsShowing: panel,
            isSearching: searching, alreadyRead: read
        )
    }

    @Test func aVerseInFrontOfTheReaderCounts() {
        #expect(ReadingPolicy.shouldCount(conditions()))
    }

    /// A verse left on screen overnight must not count when the phone is next
    /// picked up.
    @Test func aBackgroundedAppCountsNothing() {
        #expect(!ReadingPolicy.shouldCount(conditions(active: false)))
    }

    @Test func aVerseBehindTheRailDoesNotCount() {
        #expect(!ReadingPolicy.shouldCount(conditions(drawer: true)))
    }

    /// Browsing the contents is not reading.
    @Test func aVerseBehindAPanelDoesNotCount() {
        #expect(!ReadingPolicy.shouldCount(conditions(panel: true)))
    }

    @Test func aVerseBehindSearchDoesNotCount() {
        #expect(!ReadingPolicy.shouldCount(conditions(searching: true)))
    }

    @Test func anAlreadyReadVerseIsNotRecordedAgain() {
        #expect(!ReadingPolicy.shouldCount(conditions(read: true)))
    }
}
