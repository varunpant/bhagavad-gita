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
    @Environment(Settings.self) private var settings
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
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
                } header: {
                    heading("Reading")
                } footer: {
                    footnote("Sanskrit shows the Devanagari shloka with Hindi meanings. "
                             + "English shows the IAST transliteration with English meanings.")
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
                } footer: {
                    footnote("Switch everything off to read the verse on its own.")
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
            .onChange(of: settings.theme) { Haptics.selection() }
            .onChange(of: settings.textSize) { Haptics.selection() }
            .onChange(of: settings.language) { Haptics.selection() }
            .onChange(of: settings.showTranslation) { Haptics.selection() }
            .onChange(of: settings.showMeaning) { Haptics.selection() }
            .onChange(of: settings.showWordByWord) { Haptics.selection() }
        }
        .tint(theme.accent)
        .background(theme.background)
        #if os(macOS)
        // A macOS sheet sizes to its content, which for a Form means a cramped
        // column. Give it room to breathe, and let it grow with the window.
        .frame(minWidth: 460, idealWidth: 520, minHeight: 520, idealHeight: 620)
        #endif
    }

    /// A row label in the theme's own text colour.
    private func label(_ text: String) -> some View {
        Text(text).foregroundStyle(theme.textPrimary)
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(theme.textSecondary)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(theme.textSecondary.opacity(0.85))
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
        .environment(\.theme, .sepia)
}
