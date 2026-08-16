//
//  SettingsView.swift
//  Gita
//

import SwiftUI

/// Appearance, and what the reader shows.
///
/// The three content switches are the heart of it (specs.md §7.6 "language
/// visibility"): a reader who wants only the shloka, or only the shloka and the
/// word meanings, sets that once and every verse follows.
///
/// Every colour here comes from the theme. A `Form` otherwise paints its own
/// background and row fills from the system palette, which left Sepia tinting
/// only the app's own views while settings stayed system white or black.
struct SettingsView: View {
    /// A sheet brings its own title bar and Done button; a panel sits inside the
    /// rail, which already provides the way out.
    var showsChrome = true

    @Environment(Settings.self) private var settings
    @Environment(Library.self) private var library
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Set when the reader has declined notifications, so the footer can say so
    /// rather than leaving a switch that looks on but does nothing.
    @State private var reminderDenied = false

    var body: some View {
        Group {
            if showsChrome {
                NavigationStack { form }
            } else {
                form
            }
        }
        .tint(theme.accent)
        .background(theme.background)
        #if os(macOS)
        // A macOS sheet sizes to its content, which for a Form means a cramped
        // column. Give it room to breathe, and let it grow with the window.
        .frame(minWidth: 460, idealWidth: 520, minHeight: 520, idealHeight: 620)
        #endif
    }

    private var form: some View {
        @Bindable var settings = settings

        return Form {
                Section {
                    Picker(selection: $settings.theme) {
                        ForEach(ThemePreference.allCases) {
                            Text($0.displayName).foregroundStyle(theme.textPrimary).tag($0)
                        }
                    } label: {
                        label("Theme")
                    }
                    Picker(selection: $settings.textSize) {
                        ForEach(TextSize.allCases) {
                            Text($0.displayName).foregroundStyle(theme.textPrimary).tag($0)
                        }
                    } label: {
                        label("Text size")
                    }
                } header: {
                    heading("Appearance")
                }
                .listRowBackground(theme.surface)

                Section {
                    Picker(selection: $settings.language) {
                        ForEach(ReadingLanguage.allCases) {
                            Text($0.settingsName).foregroundStyle(theme.textPrimary).tag($0)
                        }
                    } label: {
                        label("Language")
                    }
                    .pickerStyle(.inline)
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $settings.immersiveReading) { label("Immersive") }
                            .accessibilityIdentifier("toggleImmersive")
                        caption("Hides the controls. Tap the top or bottom edge for them.")
                    }
                } header: {
                    heading("Reading")
                }
                .listRowBackground(theme.surface)

                Section {
                    Toggle(isOn: $settings.showTranslation) { label("Translation") }
                        .accessibilityIdentifier("toggleTranslation")
                    Toggle(isOn: $settings.showMeaning) { label("Meaning") }
                        .accessibilityIdentifier("toggleMeaning")
                    Toggle(isOn: $settings.showWordByWord) { label("Word by word") }
                        .accessibilityIdentifier("toggleWordByWord")
                } header: {
                    heading("Show beneath the shloka")
                }
                .listRowBackground(theme.surface)

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $settings.dailyReminder) { label("Daily verse") }
                            .accessibilityIdentifier("toggleDailyReminder")
                        if reminderDenied {
                            caption("Notifications are off for Gita in the Settings app.")
                        }
                    }

                    if settings.dailyReminder {
                        DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                            label("Time")
                        }
                        .accessibilityIdentifier("reminderTime")
                    }
                } header: {
                    heading("Reminder")
                }
                .listRowBackground(theme.surface)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .foregroundStyle(theme.textPrimary)
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                if showsChrome {
                    ToolbarItem(placement: .principal) {
                        Text("Settings")
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            .onChange(of: settings.theme) { Haptics.selection() }
            .onChange(of: settings.textSize) { Haptics.selection() }
            .onChange(of: settings.language) { Haptics.selection() }
            .onChange(of: settings.showTranslation) { Haptics.selection() }
            .onChange(of: settings.showMeaning) { Haptics.selection() }
            .onChange(of: settings.showWordByWord) { Haptics.selection() }
            .onChange(of: settings.immersiveReading) { Haptics.selection() }
            .onChange(of: settings.dailyReminder) { _, wanted in
                Haptics.selection()
                Task { await reminderChanged(to: wanted) }
            }
            .onChange(of: settings.reminderMinutes) {
                Haptics.selection()
                Task { await rescheduleIfOn() }
            }
    }

    /// The stored minutes-since-midnight, as the Date a picker wants.
    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: settings.reminderTime) ?? Date()
        } set: { newValue in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            settings.reminderMinutes = (parts.hour ?? 8) * 60 + (parts.minute ?? 0)
        }
    }

    /// Authorisation is only asked for when the switch is turned on, and the
    /// switch goes back if it is refused.
    private func reminderChanged(to wanted: Bool) async {
        guard wanted else {
            await DailyReminder.cancel()
            reminderDenied = false
            return
        }

        guard await DailyReminder.requestAuthorization() else {
            reminderDenied = true
            settings.dailyReminder = false
            return
        }
        reminderDenied = false
        await DailyReminder.schedule(at: settings.reminderTime, verses: library.verses)
    }

    private func rescheduleIfOn() async {
        guard settings.dailyReminder else { return }
        await DailyReminder.schedule(at: settings.reminderTime, verses: library.verses)
    }

    /// A row label in the theme's own text colour.
    private func label(_ text: String) -> some View {
        Text(text).foregroundStyle(theme.textPrimary)
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(theme.textSecondary)
    }

    /// A single line under the control it belongs to. Only where the control
    /// genuinely needs one — a caption on every row is noise, not help.
    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension ReadingLanguage {
    /// Longer than the toggle glyph — this is a list row, not a button.
    /// Settings is in English throughout, so this is too.
    var settingsName: String {
        switch self {
        case .sanskrit: "Sanskrit"
        case .english: "English"
        }
    }
}

#Preview("Sepia") {
    SettingsView()
        .environment(Settings())
        .environment(Library.preview())
        .environment(\.theme, .sepia)
}
