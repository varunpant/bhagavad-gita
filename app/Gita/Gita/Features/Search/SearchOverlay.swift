//
//  SearchOverlay.swift
//  Gita
//

import SwiftUI

/// Search as a full-screen overlay: a brand band carrying the field, over a
/// ground that covers the app completely.
///
/// Covers the rail as well as the page. Search is a mode, not a panel — while it
/// is up, nothing behind it is meant to be read or tapped, so nothing behind it
/// is visible.
struct SearchOverlay: View {
    @Environment(Library.self) private var library
    @Environment(SemanticIndex.self) private var semanticIndex
    @Environment(Settings.self) private var settings

    /// Search is opened from the rail, over the page, without leaving the
    /// reading surface — so it follows the reading language like the rest of
    /// it. This file had no notion of the setting at all: its headings, its
    /// empty state, its references and the face it set results in were English
    /// whatever the reader had chosen.
    private var isDevanagari: Bool { settings.language.isDevanagari }

    let onSelect: (Verse) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var hits: [SearchHit] = []
    @State private var related: [SearchHit] = []
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // Opaque, not a dim. At 82% the page underneath showed through as
            // ghosted Devanagari behind the results — the reader's own verse,
            // set large and faint, reading exactly like a watermark someone had
            // stamped across the search. Nothing behind search is meant to be
            // read, so nothing behind it is shown.
            Color.black
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                band
                results
            }
        }
        .task {
            focused = true
            await semanticIndex.prepare(verses: library.verses,
                                        contentVersion: library.contentVersion)
        }
        .task(id: query) { await run() }
    }

    private var band: some View {
        HStack(spacing: 12) {
            TextField(
                "",
                text: $query,
                // The placeholder was "गीता" in both languages — the same fault
                // as an English caption under a Devanagari heading, just
                // pointing the other way.
                prompt: Text(verbatim: isDevanagari ? "गीता" : "Gita")
                    .foregroundColor(.white.opacity(0.55))
            )
            .textFieldStyle(.plain)
            .font(.system(size: 34, design: .serif).italic())
            .foregroundStyle(.white)
            .tint(.white)
            .focused($focused)
            .submitLabel(.search)
            .accessibilityIdentifier("searchField")
            .accessibilityLabel("Search verses")
            #if os(iOS)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            #endif

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("searchClose")
            .accessibilityLabel("Close search")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(Brand.gradient.ignoresSafeArea(edges: .top))
    }

    @ViewBuilder
    private var results: some View {
        if query.count >= 2, hits.isEmpty, related.isEmpty {
            Text(isDevanagari ? "कुछ नहीं मिला" : "Nothing found")
                .font(isDevanagari ? .proseDevanagari : .proseLatin)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 40)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(hits) { row($0) }

                    if !related.isEmpty {
                        Text(isDevanagari ? "संबंधित" : "RELATED")
                            .font(isDevanagari ? .labelDevanagari : .label)
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 20)
                            .padding(.top, 22)
                            .padding(.bottom, 8)
                        ForEach(related) { row($0) }
                    }
                }
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func row(_ hit: SearchHit) -> some View {
        Button {
            onSelect(hit.verse)
            onDismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(hit.verse.reference(devanagari: isDevanagari))
                    .font(isDevanagari ? .labelDevanagari : .label)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
                Text(hit.snippet)
                    .font(isDevanagari ? .glossDevanagari : .glossLatin)
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Named so a test can reach a result without guessing. `app.scrollViews`
        // matches the reader's pager as readily as this list, and its first
        // button is a share icon on an off-screen page.
        .accessibilityIdentifier("searchResult")
    }

    private func run() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { hits = []; related = []; return }

        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }

        let literal = (try? await Library.search(trimmed)) ?? []
        // Checked *before* the assignment, not after: a superseded query whose
        // FTS call happened to finish last would otherwise overwrite the newer
        // results and leave the reader looking at hits for something they have
        // already typed past.
        guard !Task.isCancelled else { return }
        hits = literal

        let seen = Set(literal.map(\.verse.id))
        let semantic = await semanticIndex.search(trimmed)
        guard !Task.isCancelled else { return }
        // Library keeps the id index; building a second 701-entry dictionary
        // per keystroke to resolve at most twenty results was pure waste.
        related = semantic
            .filter { !seen.contains($0) }
            .compactMap { id in
                // The index is built over the English translation, but what is
                // *shown* is prose on the reading surface: a Devanagari reader
                // was getting English paragraphs under a Devanagari heading.
                // What it was matched on and what it reads as are two questions.
                library.verse(id: id).map {
                    let prose = isDevanagari ? $0.hindiTranslation : $0.englishTranslation
                    return SearchHit(verse: $0, snippet: prose ?? $0.sanskrit)
                }
            }
    }
}
