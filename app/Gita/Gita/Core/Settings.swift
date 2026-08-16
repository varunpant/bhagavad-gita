//
//  Settings.swift
//  Gita
//

import Foundation
import Observation
import OSLog
import SwiftUI

/// Which theme the reader asked for. Distinct from `Theme`, which is the
/// resolved palette — "System" is a preference, never a palette.
enum ThemePreference: String, CaseIterable, Identifiable, Sendable {
    case system, light, sepia, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    func resolve(for colorScheme: ColorScheme) -> Theme {
        switch self {
        case .system: Theme.resolved(for: colorScheme)
        case .light: .light
        case .sepia: .sepia
        case .dark: .dark
        }
    }
}

/// Reading text size. Rides on Dynamic Type rather than reinventing scaling —
/// every font role is declared with `relativeTo:`, so one setting moves the
/// shloka, the prose and the glosses together and in proportion.
enum TextSize: String, CaseIterable, Identifiable, Sendable {
    case small, medium, large, extraLarge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: .small
        case .medium: .large           // the system default
        case .large: .xLarge
        case .extraLarge: .xxxLarge
        }
    }
}

/// The reader's own preferences, persisted in `user.sqlite`.
///
/// Reads are synchronous off an in-memory dictionary; writes go to the database
/// off the main actor. A store that cannot be opened is not fatal — the app runs
/// on defaults and says so in the log, rather than refusing to start.
@Observable
final class Settings {
    var theme: ThemePreference = .system { didSet { persist(theme.rawValue, .theme) } }
    var language: ReadingLanguage = .sanskrit { didSet { persist(language.rawValue, .language) } }
    var textSize: TextSize = .medium { didSet { persist(textSize.rawValue, .textSize) } }

    /// Which blocks the reader draws beneath the shloka.
    ///
    /// Translation and meaning are on out of the box — that is the reading
    /// experience. The word-by-word list is study material and much longer than
    /// the verse itself, so it is opt-in.
    ///
    /// Each is written to `user.sqlite` the moment it changes, so a reader's
    /// choice holds for every future session until they change it again.
    var showTranslation = true { didSet { persist(showTranslation, .showTranslation) } }
    var showMeaning = true { didSet { persist(showMeaning, .showMeaning) } }
    var showWordByWord = false { didSet { persist(showWordByWord, .showWordByWord) } }

    /// A daily notification carrying that day's verse. Off until asked for —
    /// an unsolicited notification is the fastest way to be deleted.
    var dailyReminder = false { didSet { persist(dailyReminder, .dailyReminder) } }
    /// Minutes since midnight, so it stores as one integer rather than a date
    /// whose timezone would have to be interpreted.
    var reminderMinutes = 8 * 60 { didSet { persist(String(reminderMinutes), .reminderMinutes) } }

    /// The reminder time as hour and minute, for the picker and the trigger.
    var reminderTime: DateComponents {
        DateComponents(hour: reminderMinutes / 60, minute: reminderMinutes % 60)
    }

    /// Hide the header and footer while reading, giving the verse the whole
    /// screen. Off by default — controls that vanish have to be asked for.
    var immersiveReading = false { didSet { persist(immersiveReading, .immersiveReading) } }

    /// Where the reader last was, so opening the app resumes rather than
    /// restarting. Zero means "never read anything yet".
    var lastVerseID = 0 { didSet { persist(String(lastVerseID), .lastVerseID) } }

    private var store: UserDatabase?
    private var loading = false

    // `nonisolated` because the persist task writes from off the main actor.
    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "Settings"
    )

    private enum Key: String {
        case theme, language, textSize
        case showTranslation, showMeaning, showWordByWord
        case dailyReminder, reminderMinutes
        case lastVerseID, immersiveReading
    }

    init(store: UserDatabase? = nil) {
        #if DEBUG
        // UI tests need a known starting state; settings are durable by design,
        // so without this each test inherits whatever the last one left behind.
        if ProcessInfo.processInfo.arguments.contains("-resetSettings"),
           let url = try? UserDatabase.storeURL() {
            try? FileManager.default.removeItem(at: url)
        }
        #endif

        do {
            self.store = try store ?? UserDatabase()
            load()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-startInEnglish") {
                language = .english
            }
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-forceTheme"),
               index + 1 < arguments.count,
               let forced = ThemePreference(rawValue: arguments[index + 1]) {
                theme = forced
            }
            #endif
        } catch {
            Self.logger.error("No settings store, using defaults: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let values = try? store?.all() else { return }
        loading = true
        defer { loading = false }

        if let raw = values[Key.theme.rawValue], let value = ThemePreference(rawValue: raw) { theme = value }
        if let raw = values[Key.language.rawValue], let value = ReadingLanguage(rawValue: raw) { language = value }
        if let raw = values[Key.textSize.rawValue], let value = TextSize(rawValue: raw) { textSize = value }
        showTranslation = values[Key.showTranslation.rawValue].map { $0 == "1" } ?? true
        showMeaning = values[Key.showMeaning.rawValue].map { $0 == "1" } ?? true
        showWordByWord = values[Key.showWordByWord.rawValue].map { $0 == "1" } ?? false
        dailyReminder = values[Key.dailyReminder.rawValue].map { $0 == "1" } ?? false
        reminderMinutes = values[Key.reminderMinutes.rawValue].flatMap(Int.init) ?? 8 * 60
        lastVerseID = values[Key.lastVerseID.rawValue].flatMap(Int.init) ?? 0
        immersiveReading = values[Key.immersiveReading.rawValue].map { $0 == "1" } ?? false
    }

    private func persist(_ value: String, _ key: Key) {
        // `didSet` also fires while loading from disk; writing then would be a
        // pointless round trip back to the value we just read.
        guard !loading, let store else { return }
        Task { @concurrent in
            do { try store.set(value, for: key.rawValue) }
            catch { Self.logger.error("Could not save \(key.rawValue): \(error.localizedDescription)") }
        }
    }

    private func persist(_ value: Bool, _ key: Key) {
        persist(value ? "1" : "0", key)
    }
}
