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
    @FocusState private var searchFocused: Bool

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
        .onAppear { expandedChapter = currentVerse?.chapter }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 520, idealHeight: 640)
        #endif
    }

    // MARK: - Header

    /// Title and magnifier, or the field once the magnifier is tapped. The two
    /// occupy the same row, so opening search costs no vertical space.
    private var header: some View {
        HStack(spacing: 12) {
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
                Text("अध्याय")
                    .font(.verseReference)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }

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
                Text(chapter.devanagariNumber)
                    .font(.wordDevanagari)
                    .foregroundStyle(isCurrent(chapter) ? theme.background : theme.accent)
                    .frame(width: 34, height: 34)
                    .background {
                        Circle()
                            .fill(isCurrent(chapter) ? theme.accent : .clear)
                            .overlay(Circle().stroke(theme.accent.opacity(0.35), lineWidth: 1))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.nameSa)
                        .font(.wordDevanagari)
                        .foregroundStyle(theme.textPrimary)
                    Text(chapter.nameEn)
                        .font(.label)
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
            if hits.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(hits) { hit in
                            Button { choose(hit.verse) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(hit.verse.reference)
                                        .font(.label)
                                        .monospacedDigit()
                                        .foregroundStyle(theme.accent)
                                    marked(hit.snippet)
                                        .font(.glossLatin)
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
                }
            }
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
        guard trimmed.count >= 2 else { hits = []; return }
        // `.task(id:)` debounces and cancels: a new keystroke replaces this task
        // before the sleep finishes, so only the last query reaches the database.
        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        hits = (try? await Library.search(trimmed)) ?? []
    }
}

#Preview {
    TableOfContentsView(currentVerse: nil) { _ in }
        .environment(Library.preview())
        .environment(\.theme, .light)
}
