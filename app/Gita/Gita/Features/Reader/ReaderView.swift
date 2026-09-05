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
    @Environment(Drawer.self) private var drawer
    /// Not `progress` — that name is taken by the pager's rail position.
    @Environment(ReadingProgress.self) private var readingProgress
    @Environment(Bookmarks.self) private var bookmarks
    @Environment(\.theme) private var theme

    @State private var currentVerseID: Int?

    private var language: ReadingLanguage { settings.language }
    private var isDevanagari: Bool { language.isDevanagari }

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
            guard isReady else { return }

            if currentVerseID == nil { currentVerseID = resumeTarget() }
            openPendingDeepLink()
            // Progress counts verses on its own, but completion needs a
            // denominator and a verse-to-chapter map, and both come from the
            // corpus rather than from anything the reader has saved.
            readingProgress.adopt(verses: library.verses, chapters: library.chapters)
        }
        // Counts the verse in front of the reader once it has been there long
        // enough to have been read rather than swiped past.
        .tracksReading(of: currentVerseID)
        .onOpenURL { url in
            guard url.scheme == "gita" else { return }

            // gita://progress — the progress widget's own tap target. It opens
            // the panel the widget is a summary of, rather than dropping the
            // reader somewhere unrelated to what they tapped.
            if url.host == "progress" {
                drawer.open()
                drawer.panel = .progress
                return
            }

            // gita://verse/2/47 — from a widget, and later from Shortcuts.
            guard url.host == "verse" else { return }
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count == 2,
                  let chapter = Int(parts[0]), let sutra = Int(parts[1]) else { return }

            pendingDeepLink = (chapter, sutra)
            // A cold launch from a widget arrives before the corpus is in
            // memory, so the request is held until it is.
            if library.state.isReady { openPendingDeepLink() }
        }
        // The drawer has already put itself away — see `Drawer.requestVerse`.
        // All the reader does is take the request and clear it.
        .onChange(of: drawer.requestedVerseID) { _, requested in
            guard let requested else { return }
            currentVerseID = requested
            drawer.requestedVerseID = nil
        }
        // Switching the mode either way drops any pending hide, so the chrome
        // is never left mid-fade.
        .onChange(of: settings.immersiveReading) {
            hideChrome?.cancel()
            hideChrome = nil
            chromeRevealed = false
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
            // A swipe at either end of the book turns no page, so `onChange`
            // never fires and the gesture feels ignored rather than answered.
            // This is the only place the reader can tell the difference between
            // "nothing happened" and "there is nothing there".
            //
            // Simultaneous, so the pager still scrolls normally underneath; the
            // drawer's own edge drag is excluded by where it starts, exactly as
            // `DrawerContainer.edgeDrag` decides it.
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        guard abs(horizontal) > abs(value.translation.height),
                              !drawer.isCoveringReader,
                              value.startLocation.x > 40
                        else { return }

                        // Dragging left asks for the next verse, right for the
                        // previous one.
                        if neighbour(horizontal < 0 ? 1 : -1) == nil { Haptics.edge() }
                    }
            )
            .scrollIndicators(.hidden)
            // Double tap anywhere on the page to call the chrome back, so the
            // edge strips are a convenience rather than the only way in.
            //
            // Attached unconditionally and guarded inside: making the modifier
            // itself conditional would change the ScrollView's identity every
            // time the chrome came and went, which resets the scroll position
            // mid-read. Two taps rather than one because a single tap is how
            // you stop a fling, and stopping a fling must not summon the
            // toolbar.
            .onTapGesture(count: 2) {
                guard chromeHidden, !drawer.isCoveringReader else { return }
                revealChrome()
            }

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
            Text(currentVerse.map { verse in
                isDevanagari
                    ? "अध्याय \(verse.chapter.devanagariDigits) · श्लोक \(verse.sutra.devanagariDigits)"
                    : "Chapter \(verse.chapter) · Verse \(verse.sutra)"
            } ?? " ")
                .font(.verseReference)
                .foregroundStyle(theme.textSecondary)
                .accessibilityHidden(true)

            HStack(spacing: 6) {
                settingsButton
                Spacer()
                // Left of the bookmark, and nothing when there is nothing to
                // say: the meter is only on screen while a verse is being
                // counted or has just been marked.
                ReadMeter()
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
            ProgressBar(fraction: progress, height: 2, minimumWidth: 2)

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
                // The ramp itself when kept, not a flat sample of it: this is
                // the only place the page says a verse is kept, so it can
                // afford to be the brand rather than a yellow.
                .foregroundStyle(
                    kept ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(theme.textSecondary)
                )
                .frame(width: 32, height: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
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

    /// Both are dictionary lookups, and `currentVerse` derives from the index
    /// rather than searching again. `body` reads these several times per pass
    /// and re-runs on every frame of a page turn.
    private var currentIndex: Int? {
        currentVerseID.flatMap { library.index(of: $0) }
    }

    private var currentVerse: Verse? {
        guard let currentIndex else { return library.verses.first }
        return library.verses[currentIndex]
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
        if settings.lastVerseID != 0, let saved = library.verse(id: settings.lastVerseID) {
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
    @Environment(\.theme) private var theme

    /// Decoded once per page, not once per read.
    ///
    /// This is a `JSONDecoder` parse of the stored word list, and it was a
    /// computed property that `body` asked for twice — once to test emptiness,
    /// once to draw the list — for each of the three pages the pager keeps
    /// resident, on every pass. The comment here used to say "decoded once per
    /// body pass", which conceded the cost rather than removing it.
    ///
    /// `app/CLAUDE.md` on the reader: "Verse leaves must be cheap — no
    /// attributed-string building or date formatting inside `body`. Precompute
    /// on load." A `let` set when the page is made is that precomputation.
    private let words: [WordMeaning]
    private var isDevanagari: Bool { language.isDevanagari }

    init(verse: Verse, language: ReadingLanguage, settings: Settings) {
        self.verse = verse
        self.language = language
        self.settings = settings
        self.words = verse.words(for: language)
    }

    var body: some View {
        // The height is needed to know whether the page even fills the screen,
        // and there is no way to ask for "at least the container" without it.
        // The usual objection to `GeometryReader` does not apply here: this page
        // is one verse in a plain `VStack`, not a lazy list whose laziness it
        // would defeat.
        GeometryReader { geometry in
            page(minHeight: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func page(minHeight: CGFloat) -> some View {
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

                // Last, under everything the reader has turned on. Sharing is
                // what you do once you have finished with a verse, so the bar
                // sits at the end of it rather than interrupting between the
                // shloka and its translation.
                if settings.showShareBar {
                    ShareBar(verse: verse, language: language)
                        .padding(.top, 4)
                }
            }
            // A comfortable measure, centred — the text column never stretches
            // to fill a wide iPad or Mac window (specs.md section 13).
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 36)
            // Centred in both modes. With most sections turned off — the shloka
            // and its meaning, say — a page is far shorter than the screen, and
            // top-aligned it hugged the header with the rest of the screen
            // empty. In normal reading the container is the band between the
            // header and the footer, so the verse centres in that; in immersive
            // it is the whole screen.
            //
            // `minHeight`, not `height`: a page longer than the screen grows
            // past it and scrolls as it always did.
            .frame(minHeight: minHeight, alignment: .center)
        }
        .scrollIndicators(.hidden)
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
        // Nothing on the shloka itself — no glyph before its first line, no
        // rule under it. Both marked the verse by decorating the one thing on
        // the page that should carry no decoration; the header's bookmark
        // fills with the brand ramp instead, which is where the reader put the
        // mark in the first place.
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

    /// Word and gloss, one pair per row, the boundary between them on the
    /// page's own centre line.
    ///
    /// A `Grid` keeps the two columns aligned to one shared boundary — rows in a
    /// stack of HStacks would each size independently and the glosses would
    /// stagger.
    ///
    /// **Both columns are flexible and equal**, which is what puts that
    /// boundary in the middle and keeps it there. The word column used to be a
    /// fixed 150pt and the gloss column its natural width, with the whole grid
    /// centred as a block; that centres the *table* but not the *gutter*. With
    /// a 150pt column in a 376pt measure the boundary fell 42pt left of centre,
    /// so every short word sat left of the middle and every gloss leaned right
    /// of it — and because the grid's width came from the longest gloss, the
    /// whole arrangement shifted whenever the face or the wording changed. It
    /// moved visibly when the Latin face became Inter, whose glosses set wider
    /// than Georgia's at the same size. Two equal halves cannot drift: words
    /// end at the centre, meanings begin there, in either script and at every
    /// text size.
    ///
    /// The grid must not carry `.fixedSize(horizontal: true)`. That tells it to
    /// take its *ideal* width and ignore the width it was offered — in
    /// Devanagari the ideal fits a phone and nobody noticed, but the English
    /// transliteration is sandhi-compounded into single 30-character words, so
    /// the grid drew itself far wider than the screen and the list hung off
    /// both edges.
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
                            // Half the measure, and wrapping inside it rather
                            // than pushing the row wider. Devanagari words are
                            // short; their transliterations are sandhi-compounded
                            // — "kārpaṇya-doṣa-upahata-svabhāvaḥ" is one word —
                            // and a column sized to *that* would leave the
                            // meanings a ribbon.
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(word.m)
                            .font(isDevanagari ? .glossDevanagari : .glossLatin)
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .gridColumnAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity)
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

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
