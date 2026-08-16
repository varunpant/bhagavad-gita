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
    @Environment(SemanticIndex.self) private var semanticIndex
    @Environment(Drawer.self) private var drawer
    @Environment(Bookmarks.self) private var bookmarks
    @Environment(\.theme) private var theme

    @State private var currentVerseID: Int?

    private var language: ReadingLanguage { settings.language }

    /// A verse asked for by a widget before the corpus finished loading.
    @State private var pendingDeepLink: (chapter: Int, sutra: Int)?

    /// Chrome brought back by tapping an edge, and the task that hides it again.
    @State private var chromeRevealed = false
    @State private var hideChrome: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverRunning

    /// Chrome is hidden only when asked for, and never from VoiceOver — a
    /// control that cannot be found by touch cannot be found at all.
    private var chromeHidden: Bool {
        settings.immersiveReading && !chromeRevealed && !voiceOverRunning
    }

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
            if isReady, currentVerseID == nil { currentVerseID = resumeTarget() }
            if isReady { openPendingDeepLink() }
        }
        .onOpenURL { url in
            // gita://verse/2/47 — from a widget, and later from Shortcuts.
            guard url.scheme == "gita", url.host == "verse" else { return }
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count == 2,
                  let chapter = Int(parts[0]), let sutra = Int(parts[1]) else { return }

            pendingDeepLink = (chapter, sutra)
            // A cold launch from a widget arrives before the corpus is in
            // memory, so the request is held until it is.
            if library.state.isReady { openPendingDeepLink() }
        }
        .onChange(of: drawer.requestedVerseID) { _, requested in
            guard let requested else { return }
            currentVerseID = requested
            drawer.requestedVerseID = nil
            // Asking for a verse means "take me there", so the rail and any
            // panel go with it. Done here, where the request is consumed,
            // rather than in the panel that raised it — the panel is being torn
            // down at that moment, which is a poor place to expect more work.
            drawer.isOpen = false
            drawer.panel = nil
        }
        .onChange(of: settings.immersiveReading) { _, immersive in
            hideChrome?.cancel()
            chromeRevealed = false
            // Leaving immersive mode should not leave the chrome mid-fade.
            if !immersive { hideChrome = nil }
        }
        .onChange(of: currentVerseID) { previous, current in
            guard let current, previous != current else { return }

            // Saved on every move rather than on backgrounding: an app killed
            // from the switcher, or crashed, never gets a chance to save later,
            // and a single integer write is far cheaper than the risk.
            settings.lastVerseID = current

            // Every route to another verse — swipe, chevron, contents, a widget
            // link — passes through this one property, so the feedback belongs
            // here rather than at four call sites that could drift apart.
            guard previous != nil else { return }
            Haptics.pageTurn()
        }
    }

    // MARK: - Reader

    private var reader: some View {
        VStack(spacing: 0) {
            if !chromeHidden {
                header.transition(.move(edge: .top).combined(with: .opacity))
            }

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

            if !chromeHidden {
                footer.transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // The reveal targets sit above the page rather than being part of it, so
        // a horizontal swipe still reaches the pager underneath and turning the
        // page never brings the chrome back — only a deliberate tap does.
        .overlay(alignment: .top) { revealEdge(.top) }
        .overlay(alignment: .bottom) { revealEdge(.bottom) }
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: chromeHidden)
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

    /// A tap strip along an edge, present only while the chrome is hidden.
    ///
    /// The bottom strip reaches into the safe area, because the home-indicator
    /// band is exactly where a thumb goes. The top one deliberately does not:
    /// taps in the status bar are consumed by the system before the app sees
    /// them, so a strip drawn up there would simply be dead.
    @ViewBuilder
    private func revealEdge(_ edge: Edge) -> some View {
        if chromeHidden {
            Color.clear
                .frame(height: 72)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .onTapGesture { revealChrome() }
                .ignoresSafeArea(edges: edge == .bottom ? .bottom : [])
                .accessibilityHidden(true)
        }
    }

    /// Show the controls, then take them away again shortly — long enough to
    /// reach one, short enough not to become the normal state.
    private func revealChrome() {
        hideChrome?.cancel()
        chromeRevealed = true
        hideChrome = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            chromeRevealed = false
        }
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
                bookmarkButton
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
            drawer.open()
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17, weight: .regular))
                .frame(width: 32, height: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textSecondary)
        // Gone the instant the rail opens, with no animation of its own: the
        // rail's gear takes over on the same line, and watching this glyph slide
        // away underneath it was the distracting part.
        .opacity(drawer.isOpen ? 0 : 1)
        .animation(nil, value: drawer.isOpen)
        .accessibilityIdentifier("menuButton")
        .accessibilityLabel("Menu")
    }

    private var footer: some View {
        VStack(spacing: 12) {
            ProgressRail(progress: progress, theme: theme)

            HStack {
                stepButton(direction: -1, symbol: "chevron.left", label: "Previous verse")
                Spacer()
                // Plain text: the contents belongs to the rail now, and a
                // reference that silently opened a panel was a second, hidden
                // way in.
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

    private var bookmarkButton: some View {
        let kept = currentVerse.map { bookmarks.contains($0.id) } ?? false

        return Button {
            guard let verse = currentVerse else { return }
            bookmarks.toggle(verse.id) ? Haptics.pageTurn() : Haptics.selection()
        } label: {
            Image(systemName: kept ? "bookmark.fill" : "bookmark")
                .font(.system(size: 17, weight: .regular))
                .frame(width: 32, height: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(kept ? theme.accent : theme.textSecondary)
        .accessibilityIdentifier("bookmarkButton")
        .accessibilityLabel(kept ? "Remove bookmark" : "Bookmark this verse")
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

    /// Where to open: where the reader left off, or the beginning.
    ///
    /// The saved verse is looked up rather than trusted — a content update can
    /// renumber ids, and resuming into nothing would leave a blank reader.
    private func resumeTarget() -> Int? {
        if settings.lastVerseID != 0,
           let saved = library.verses.first(where: { $0.id == settings.lastVerseID }) {
            return saved.id
        }
        return library.verses.first?.id
    }

    private func openPendingDeepLink() {
        guard let target = pendingDeepLink else { return }
        pendingDeepLink = nil
        guard let verse = library.verses.first(
            where: { $0.chapter == target.chapter && $0.sutra == target.sutra }
        ) else { return }
        currentVerseID = verse.id
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
    @Environment(Bookmarks.self) private var bookmarks
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

    private var isKept: Bool { bookmarks.contains(verse.id) }

    private var shloka: some View {
        VStack(spacing: 14) {
            ForEach(Array(verse.displayLines(for: language).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(isDevanagari ? .shloka : .shlokaLatin)
                    .foregroundStyle(theme.textPrimary)
                    // Dotted and faint: a mark on the shloka, not an emphasis
                    // of it. A solid rule competes with the Devanagari, which
                    // already carries a headline across every word.
                    .underline(isKept, pattern: .dot, color: theme.accent.opacity(0.22))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
            }
        }
        .frame(maxWidth: .infinity)
        // An overlay, so the glyph appearing never shifts the text it marks.
        .overlay(alignment: .topLeading) {
            if isKept {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.accent)
                    .offset(y: -4)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
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
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
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
            // Position is the row identity, so the two languages' lists must not
            // be diffed against each other — rebuild outright on a switch.
            .id(language)
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
