//
//  DailyReminder.swift
//  Gita
//

import Foundation
import OSLog
import UserNotifications

/// One gentle notification a day, carrying that day's verse (specs.md §11).
///
/// Notifications are scheduled a fortnight ahead rather than as one repeating
/// trigger: a repeating trigger reuses the same text every day, and the whole
/// point is that each day brings a different verse. Rescheduling on launch keeps
/// the window full for anyone who opens the app even occasionally.
nonisolated enum DailyReminder {
    /// How many days to fill. iOS caps pending notifications at 64 per app, so
    /// this stays well clear while covering a fortnight away from the app.
    static let horizon = 14
    private nonisolated static let identifierPrefix = "daily-verse-"

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "DailyReminder"
    )

    /// Ask once. Returns false if the reader declines, which the caller uses to
    /// put the switch back rather than leaving it on and silently doing nothing.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Async rather than the callback form: the completion variant would have
    /// to capture the non-Sendable notification centre in a @Sendable closure.
    static func cancel() async {
        let centre = UNUserNotificationCenter.current()
        let pending = await centre.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        centre.removePendingNotificationRequests(withIdentifiers: ours)
    }

    /// Top the schedule up, but only for a reader who has already said yes.
    ///
    /// Adding a request when authorization is undetermined puts the system's
    /// permission alert on screen — on macOS `add` alone is enough to do it,
    /// without anyone calling `requestAuthorization`. That is fine when the
    /// reader has just reached for the switch and catastrophic on launch: it
    /// asks a question nobody prompted, and under a test host it stops the run
    /// dead waiting for a human to click something.
    ///
    /// So the launch-time refill goes through here, and only the switch in
    /// Settings is allowed to ask.
    static func refillIfAuthorized(
        at time: DateComponents, verses: [Verse], calendar: Calendar = .current
    ) async {
        let status = await UNUserNotificationCenter.current().notificationSettings()
            .authorizationStatus
        guard status == .authorized || status == .provisional else {
            logger.info("Not authorised (\(status.rawValue)); leaving the schedule alone")
            return
        }
        await schedule(at: time, verses: verses, calendar: calendar)
    }

    /// Replace the schedule with one notification per day at `time`, starting
    /// with the next occurrence.
    static func schedule(at time: DateComponents, verses: [Verse], calendar: Calendar = .current) async {
        await cancel()
        guard !verses.isEmpty, let hour = time.hour, let minute = time.minute else { return }

        let centre = UNUserNotificationCenter.current()
        let now = Date()

        for offset in 0 ..< horizon {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(
                      bySettingHour: hour, minute: minute, second: 0, of: day
                  ),
                  fireDate > now,                      // never schedule into the past
                  let verse = DailyVerse.verse(for: fireDate, in: verses, calendar: calendar)
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = "श्लोक \(verse.reference)"
            content.body = verse.englishTranslation ?? verse.sanskrit
            content.sound = .default
            content.userInfo = ["chapter": verse.chapter, "sutra": verse.sutra]

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(verse.chapter)-\(verse.sutra)-\(offset)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            do { try await centre.add(request) }
            catch { logger.error("Could not schedule day \(offset): \(error.localizedDescription)") }
        }

        logger.info("Scheduled up to \(horizon) daily verses at \(hour):\(minute)")
    }
}
