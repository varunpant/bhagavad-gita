//
//  ReaderView.swift
//  Gita
//

import SwiftUI

/// One shloka at a time.
///
/// A horizontally paging scroll view: each page is exactly one verse, snapped to
/// the container edge. `LazyHStack` means only the pages either side of the
/// current one are built, so all 701 verses behave like one document without
/// ever rendering more than three.
struct ReaderView: View {
    @Environment(Library.self) private var library
    @Environment(Settings.self) private var settings
    @Environment(\.theme) private var theme

    @State private var currentVerseID: Int?
    /// Debug builds can open straight into settings, for screenshots and tests.
    @State private var showingSettings = ProcessInfo.processInfo.arguments.contains("-openSettings")

    private var language: ReadingLanguage { settings.language }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            switch library.state {
            case .loading:
                ProgressView()
                    .tint(theme.accent)
            case .failed(let message):
                ContentUnavailableView(
                    "Text unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .ready:
                reader
            }
        }
        .task { await library.load() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .onChange(of: library.state.isReady, initial: true) { _, isReady in
            if isReady, currentVerseID == nil { currentVerseID = library.verses.first?.id }
        }
    }

    // MARK: - Reader

    private var reader: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(library.verses) { verse in
                        ShlokaPage(verse: verse, language: language, settings: settings)
                            .containerRelativeFrame(.horizontal)
                            .id(verse.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentVerseID)
            .scrollIndicators(.hidden)

            footer
        }
        #if os(macOS)
        // Focusable so the arrow keys reach the reader — but without the focus
        // ring AppKit would otherwise draw around the whole page, which reads as
        // a selection highlight rather than as chrome.
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { step(-1); return .handled }
        .onKeyPress(.rightArrow) { step(1); return .handled }
        #endif
    }

    private var header: some View {
        ZStack {
            Text(currentVerse.map { "अध्याय \($0.chapter) · श्लोक \($0.sutra)" } ?? " ")
                .font(.verseReference)
                .foregroundStyle(theme.textSecondary)
                .accessibilityHidden(true)

            HStack {
                settingsButton
                Spacer()
                languageToggle
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(theme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)
        }
    }

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textSecondary)
        .accessibilityIdentifier("settingsButton")
        .accessibilityLabel("Settings")
    }

    /// Flips the scripture and the word meanings together. Sits on the right of
    /// the header, showing the script it will switch *to*.
    private var languageToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { settings.language = language.toggled }
        } label: {
            Text(language.toggled.icon)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.accent.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.accent.opacity(0.25), lineWidth: 1)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.accent)
        .accessibilityIdentifier("languageToggle")
        .accessibilityLabel("Switch to \(language.toggled.accessibilityName)")
    }

    private var footer: some View {
        VStack(spacing: 12) {
            ProgressRail(progress: progress, theme: theme)

            HStack {
                stepButton(direction: -1, symbol: "chevron.left", label: "Previous verse")
                Spacer()
                Text(currentVerse?.reference ?? "")
                    .font(.label)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityIdentifier("verseReference")
                Spacer()
                stepButton(direction: 1, symbol: "chevron.right", label: "Next verse")
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func stepButton(direction: Int, symbol: String, label: String) -> some View {
        Button {
            step(direction)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.accent)
        .disabled(neighbour(direction) == nil)
        .opacity(neighbour(direction) == nil ? 0.25 : 1)
        .accessibilityLabel(label)
    }

    // MARK: - Position

    private var currentVerse: Verse? {
        guard let currentVerseID else { return library.verses.first }
        return library.verses.first { $0.id == currentVerseID }
    }

    private var currentIndex: Int? {
        guard let currentVerseID else { return nil }
        return library.verses.firstIndex { $0.id == currentVerseID }
    }

    private var progress: Double {
        guard let currentIndex, library.verses.count > 1 else { return 0 }
        return Double(currentIndex) / Double(library.verses.count - 1)
    }

    private func neighbour(_ direction: Int) -> Verse? {
        guard let currentIndex else { return nil }
        return library.verses[safe: currentIndex + direction]
    }

    private func step(_ direction: Int) {
        guard let next = neighbour(direction) else { return }
        withAnimation(.snappy(duration: 0.28)) {
            currentVerseID = next.id
        }
    }
}

// MARK: - One page

private struct ShlokaPage: View {
    let verse: Verse
    let language: ReadingLanguage
    let settings: Settings
    @Environment(\.theme) private var theme

    private var words: [WordMeaning] { verse.words(for: language) }
    private var isDevanagari: Bool { language == .sanskrit }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 30) {
                shloka

                if settings.showTranslation, let translation = verse.translation(for: language) {
                    section(isDevanagari ? "अनुवाद" : "TRANSLATION", body: translation)
                }

                if settings.showMeaning, let meaning = verse.meaning(for: language) {
                    section(isDevanagari ? "भावार्थ" : "MEANING", body: meaning)
                }

                if settings.showWordByWord, !words.isEmpty {
                    wordList
                }

                if !verse.isEnriched, showsAnythingBelowTheShloka {
                    notYetEnriched
                }
            }
            // A comfortable measure, centred — the text column never stretches
            // to fill a wide iPad or Mac window (specs.md section 13).
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 36)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Blocks

    private var shloka: some View {
        VStack(spacing: 14) {
            ForEach(Array(verse.displayLines(for: language).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(isDevanagari ? .shloka : .shlokaLatin)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter \(verse.chapter), verse \(verse.sutra)")
        .accessibilityValue(Text(spokenShloka))
    }

    /// A labelled block of prose — the translation and the explanation share
    /// this shape so they read as siblings rather than as two separate designs.
    private func section(_ title: String, body: String) -> some View {
        VStack(spacing: 10) {
            heading(title)
            Text(body)
                .font(isDevanagari ? .proseDevanagari : .proseLatin)
                .foregroundStyle(theme.textPrimary.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// Word and gloss, one pair per row, the whole table centred on the page.
    ///
    /// A `Grid` keeps the two columns aligned to one shared boundary — rows in a
    /// stack of HStacks would each size independently and the glosses would
    /// stagger. The grid then sizes to its content, so centring the grid centres
    /// the table as a block while the columns stay tidily aligned inside it.
    private var wordList: some View {
        VStack(spacing: 14) {
            heading(isDevanagari ? "शब्दार्थ" : "WORD BY WORD")

            Grid(alignment: .top, horizontalSpacing: 18, verticalSpacing: 12) {
                ForEach(words) { word in
                    GridRow {
                        Text(word.w)
                            .font(isDevanagari ? .wordDevanagari : .wordLatin)
                            .foregroundStyle(theme.accent)
                            .multilineTextAlignment(.trailing)
                            .gridColumnAlignment(.trailing)
                        Text(word.m)
                            .font(isDevanagari ? .glossDevanagari : .glossLatin)
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .gridColumnAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity)
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.label)
            .tracking(1.2)
            .foregroundStyle(theme.textSecondary)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.divider)
                    .frame(height: 1)
                    .offset(y: 6)
            }
    }

    /// With every switch off, an un-enriched verse looks exactly like an
    /// enriched one — so the "not generated yet" note would be noise.
    private var showsAnythingBelowTheShloka: Bool {
        settings.showTranslation || settings.showMeaning || settings.showWordByWord
    }

    private var notYetEnriched: some View {
        Text("Translation and word meanings for this verse have not been generated yet.")
            .font(.label)
            .foregroundStyle(theme.textSecondary.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    /// Tagging the value as Sanskrit makes VoiceOver reach for a Devanagari
    /// voice instead of reading the shloka with an English one. SwiftUI has no
    /// `.accessibilityLanguage` modifier — the language rides on the string.
    private var spokenShloka: AttributedString {
        var text = AttributedString(verse.sanskrit)
        text.languageIdentifier = "sa"
        return text
    }
}

// MARK: - Progress rail

private struct ProgressRail: View {
    let progress: Double
    let theme: Theme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.divider)
                Capsule()
                    .fill(theme.accent)
                    .frame(width: max(2, proxy.size.width * progress))
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Helpers

private extension Library.State {
    var isReady: Bool { if case .ready = self { true } else { false } }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Reader") {
    ReaderView()
        .environment(Library.preview())
        .environment(Settings())
        .environment(\.theme, .light)
}

#Preview("Sepia") {
    ReaderView()
        .environment(Library.preview())
        .environment(Settings())
        .environment(\.theme, .sepia)
}
