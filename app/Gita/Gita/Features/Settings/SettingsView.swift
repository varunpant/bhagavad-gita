//
//  SettingsView.swift
//  Gita
//

import SwiftUI

/// Appearance, what the reader shows, and where the text came from.
///
/// The three content switches are the heart of it (specs.md §7.6 "language
/// visibility"): a reader who wants only the shloka, or only the shloka and the
/// word meanings, sets that once and every verse follows.
struct SettingsView: View {
    @Environment(Settings.self) private var settings
    @Environment(Library.self) private var library
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(ThemePreference.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Text size", selection: $settings.textSize) {
                        ForEach(TextSize.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                Section {
                    Picker("Language", selection: $settings.language) {
                        ForEach(ReadingLanguage.allCases) { Text($0.settingsName).tag($0) }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Reading")
                } footer: {
                    Text("Sanskrit shows the Devanagari shloka with Hindi meanings. "
                         + "English shows the IAST transliteration with English meanings.")
                }

                Section {
                    Toggle("Translation", isOn: $settings.showTranslation)
                    .accessibilityIdentifier("toggleTranslation")

                    Toggle("Meaning", isOn: $settings.showMeaning)
                    .accessibilityIdentifier("toggleMeaning")

                    Toggle("Word by word", isOn: $settings.showWordByWord)
                    .accessibilityIdentifier("toggleWordByWord")
                } header: {
                    Text("Show beneath the shloka")
                } footer: {
                    Text("Switch everything off to read the verse on its own.")
                }

                Section {
                    LabeledContent("Verses", value: "\(library.verses.count)")
                    LabeledContent("With translation", value: "\(library.enrichedCount)")
                    Link("bhagwadgita.info", destination: URL(string: "https://bhagwadgita.info")!)
                } header: {
                    Text("About")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(theme.accent)
        #if os(macOS)
        // A macOS sheet sizes to its content, which for a Form means a cramped
        // column. Give it room to breathe, and let it grow with the window.
        .frame(minWidth: 460, idealWidth: 520, minHeight: 520, idealHeight: 620)
        #endif
    }

    /// Devanagari name with its English gloss underneath — the same words the
    /// reader sees as section headings on the verse page.
    private func label(_ devanagari: String, _ english: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(devanagari)
            Text(english)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

#Preview {
    SettingsView()
        .environment(Settings())
        .environment(Library.preview())
        .environment(\.theme, .light)
}
