//
//  TableOfContentsView.swift
//  Gita
//

import SwiftUI

/// The eighteen chapters, and a way to reach any verse.
///
/// Opened by tapping the verse reference in the reader's footer. The resting
/// state is pure content — no search bar, no chrome. A single magnifier in the
/// header expands a field only when asked for, and collapses back to an icon.
struct TableOfContentsView: View {
    @Environment(Library.self) private var library
    @Environment(SemanticIndex.self) private var semanticIndex
    @Environment(Settings.self) private var settings
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Where the reader currently is, so the list can open there.
    let currentVerse: Verse?
    /// Called with the chosen verse; the sheet dismisses itself.
    let onSelect: (Verse) -> Void

    @State private var expandedChapter: Int?
    @State private var searching = false
    @State private var query = ""
    @State private var hits: [SearchHit] = []
    /// Ids that only semantic search found — shown under their own heading, so
    /// a reader can tell "these contain your words" from "these are about it".
    @State private var relatedHits: [SearchHit] = []
    @FocusState private var searchFocused: Bool

    /// Seeded from the reader's language when the sheet opens, then owned by
    /// the sheet. Browsing the contents in English while reading in Sanskrit is
    /// a reasonable thing to want, and it should not change what the reader
    /// shows when the sheet closes.
    @State private var language: ReadingLanguage = .sanskrit

    private var isDevanagari: Bool { language == .sanskrit }

    var body: some View {
        VStack(spacing: 0) {
            header

            if searching, !query.isEmpty {
                results
            } else {
                chapterList
            }
        }
        .background(theme.background)
        .task(id: query) { await runSearch() }
        .onAppear {
            expandedChapter = currentVerse?.chapter
            language = settings.language
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 520, idealHeight: 640)
        #endif
    }

    // MARK: - Header

    /// Title and magnifier, or the field once the magnifier is tapped. The two
    /// occupy the same row, so opening search costs no vertical space.
    private var header: some View {
        HStack(spacing: 12) {
            // A chevron rather than a second xmark: the magnifier's close button
            // is already an xmark, and two of them in one row would be ambiguous.
            // On Mac this is the only way out at all — a sheet there has no
            // swipe-to-dismiss.
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .accessibilityIdentifier("tocClose")
            .accessibilityLabel("Close contents")

            if searching {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                TextField("", text: $query, prompt: Text(verbatim: "…").foregroundColor(theme.textSecondary))
                    .textFieldStyle(.plain)
                    .font(.proseLatin)
                    .foregroundStyle(theme.textPrimary)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .accessibilityIdentifier("tocSearchField")
                    .accessibilityLabel("Search verses")
                #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                #endif
            } else {
                Text(isDevanagari ? "अध्याय" : "CHAPTERS")
                    .font(isDevanagari ? .verseReference : .label)
                    .tracking(isDevanagari ? 0 : 1.2)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }

            languageToggle

            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    searching.toggle()
                    if !searching { query = "" }
                }
                searchFocused = searching
            } label: {
                Image(systemName: searching ? "xmark" : "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 34, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accent)
            .accessibilityIdentifier("tocSearchToggle")
            .accessibilityLabel(searching ? "Close search" : "Search")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.divider).frame(height: 1)
        }
    }

    /// Same control as the reader's, showing the script it switches *to*.
    private var languageToggle: some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy(duration: 0.2)) {
                language = language.toggled
            }
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
        .accessibilityIdentifier("tocLanguageToggle")
        .accessibilityLabel("Switch to \(language.toggled.accessibilityName)")
    }

    // MARK: - Chapters

    private var chapterList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(library.chapters) { chapter in
                        chapterRow(chapter)
                        if expandedChapter == chapter.id {
                            verseGrid(for: chapter)
                        }
                        Rectangle().fill(theme.divider).frame(height: 1)
                    }
                }
            }
            .onAppear {
                if let chapter = currentVerse?.chapter {
                    proxy.scrollTo(chapter, anchor: .top)
                }
            }
        }
    }

    private func chapterRow(_ chapter: Chapter) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                expandedChapter = expandedChapter == chapter.id ? nil : chapter.id
            }
        } label: {
            HStack(spacing: 14) {
                // The chapter number as a Devanagari numeral in a ring, rather
                // than the word "Chapter" repeated eighteen times.
                Text(isDevanagari ? chapter.devanagariNumber : "\(chapter.id)")
                    .font(isDevanagari ? .wordDevanagari : .wordLatin)
                    .monospacedDigit()
                    .foregroundStyle(isCurrent(chapter) ? theme.background : theme.accent)
                    .frame(width: 34, height: 34)
                    .background {
                        Circle()
                            .fill(isCurrent(chapter) ? theme.accent : .clear)
                            .overlay(Circle().stroke(theme.accent.opacity(0.35), lineWidth: 1))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isDevanagari ? chapter.nameSa : chapter.nameEn)
                        .font(isDevanagari ? .wordDevanagari : .wordLatin)
                        .foregroundStyle(theme.textPrimary)
                    Text(isDevanagari ? chapter.nameEn : chapter.nameSa)
                        .font(isDevanagari ? .label : .glossDevanagari)
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Text("\(chapter.verseCount)")
                    .font(.label)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary.opacity(0.7))

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
                    .rotationEffect(.degrees(expandedChapter == chapter.id ? 90 : 0))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .id(chapter.id)
        .accessibilityIdentifier("chapter-\(chapter.id)")
        .accessibilityLabel("Chapter \(chapter.id), \(chapter.nameEn), \(chapter.verseCount) verses")
    }

    /// Verse numbers as a grid of chips — compact enough that even chapter 18's
    /// 78 verses stay reachable without a long scroll.
    private func verseGrid(for chapter: Chapter) -> some View {
        let verses = library.verses.filter { $0.chapter == chapter.id }
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 8)], spacing: 8) {
            ForEach(verses) { verse in
                Button {
                    choose(verse)
                } label: {
                    Text("\(verse.sutra)")
                        .font(.label)
                        .monospacedDigit()
                        .foregroundStyle(verse.id == currentVerse?.id ? theme.background : theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(verse.id == currentVerse?.id ? theme.accent : theme.surface)
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Verse \(verse.chapter).\(verse.sutra)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Results

    private var results: some View {
        Group {
            if hits.isEmpty && relatedHits.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(hits) { resultRow($0) }

                        if !relatedHits.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text("RELATED")
                            }
                            .font(.label)
                            .tracking(1.2)
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                            .padding(.bottom, 8)
                            .accessibilityIdentifier("relatedHeading")

                            ForEach(relatedHits) { resultRow($0) }
                        }
                    }
                }
            }
        }
    }

    private func resultRow(_ hit: SearchHit) -> some View {
        VStack(spacing: 0) {
            Button { choose(hit.verse) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hit.verse.reference)
                        .font(.label)
                        .monospacedDigit()
                        .foregroundStyle(theme.accent)
                    marked(hit.snippet)
                        .font(isDevanagari ? .glossDevanagari : .glossLatin)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Rectangle().fill(theme.divider).frame(height: 1)
        }
    }

    /// FTS5 marks the matched terms with invisible sentinels rather than markup,
    /// so a verse containing literal `<b>` cannot forge its own highlighting.
    private func marked(_ snippet: String) -> Text {
        snippet.split(separator: "\u{2062}", omittingEmptySubsequences: false)
            .enumerated()
            .reduce(Text("")) { result, part in
                let pieces = part.element.split(separator: "\u{2063}", omittingEmptySubsequences: false)
                guard part.offset > 0, let match = pieces.first else {
                    return result + Text(String(part.element))
                }
                let rest = pieces.dropFirst().joined(separator: "")
                return result
                    + Text(String(match)).foregroundColor(theme.textPrimary).bold()
                    + Text(rest)
            }
    }

    // MARK: - Actions

    private func isCurrent(_ chapter: Chapter) -> Bool {
        currentVerse?.chapter == chapter.id
    }

    private func choose(_ verse: Verse) {
        onSelect(verse)
        dismiss()
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { hits = []; relatedHits = []; return }
        // `.task(id:)` debounces and cancels: a new keystroke replaces this task
        // before the sleep finishes, so only the last query reaches the database.
        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }

        let literal = (try? await Library.search(trimmed)) ?? []
        hits = literal
        guard !Task.isCancelled else { return }

        // Semantic results fill in behind the literal ones, never displacing
        // them: someone typing "2.47" or "krishna" wants the exact match first.
        let seen = Set(literal.map(\.verse.id))
        let related = await semanticIndex.search(trimmed)
        let byId = Dictionary(uniqueKeysWithValues: library.verses.map { ($0.id, $0) })
        relatedHits = related
            .filter { !seen.contains($0) }
            .compactMap { id in
                byId[id].map { verse in
                    SearchHit(verse: verse,
                              snippet: verse.translation(for: language) ?? verse.sanskrit)
                }
            }
    }
}

#Preview {
    TableOfContentsView(currentVerse: nil) { _ in }
        .environment(Library.preview())
        .environment(SemanticIndex())
        .environment(Settings())
        .environment(\.theme, .light)
}
