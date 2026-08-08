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
    @Environment(\.theme) private var theme

    @State private var currentVerseID: Int?
    @State private var language: ReadingLanguage = .launchDefault

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
                        ShlokaPage(verse: verse, language: language)
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
        .focusable()
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
                Spacer()
                languageToggle
            }
            .padding(.trailing, 16)
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

    /// Flips the scripture and the word meanings together. Sits on the right of
    /// the header, showing the script it will switch *to*.
    private var languageToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { language = language.toggled }
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
    @Environment(\.theme) private var theme

    private var words: [WordMeaning] { verse.words(for: language) }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 32) {
                shloka
                if !words.isEmpty {
                    Divider().background(theme.divider)
                    wordList
                } else if !verse.isEnriched {
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

    private var shloka: some View {
        VStack(spacing: 16) {
            ForEach(Array(Verse.lines(of: verse.scripture(for: language)).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(language == .sanskrit ? .shloka : .shlokaLatin)
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

    /// Word and gloss, one pair per row. A `Grid` keeps the glosses aligned in a
    /// column no matter how long the words are — the thing a plain HStack per
    /// row cannot do, since each row would size independently.
    private var wordList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language == .sanskrit ? "शब्दार्थ" : "WORD BY WORD")
                .font(.label)
                .tracking(1.2)
                .foregroundStyle(theme.textSecondary)

            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 12) {
                ForEach(words) { word in
                    GridRow {
                        Text(word.w)
                            .font(language == .sanskrit ? .wordDevanagari : .wordLatin)
                            .foregroundStyle(theme.accent)
                            .gridColumnAlignment(.leading)
                        Text(word.m)
                            .font(language == .sanskrit ? .glossDevanagari : .glossLatin)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notYetEnriched: some View {
        Text("Word meanings for this verse have not been generated yet.")
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
        .environment(\.theme, .light)
}

#Preview("Sepia") {
    ReaderView()
        .environment(Library.preview())
        .environment(\.theme, .sepia)
}
