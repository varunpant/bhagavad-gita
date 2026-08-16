//
//  BookmarksView.swift
//  Gita
//

import SwiftUI

/// The verses the reader has kept.
///
/// Shown as a panel from the rail, in reading order rather than the order they
/// were added: a reader looking for something they marked thinks of where it is
/// in the book, not when they marked it.
struct BookmarksView: View {
    @Environment(Library.self) private var library
    @Environment(Bookmarks.self) private var bookmarks
    @Environment(Settings.self) private var settings
    @Environment(\.theme) private var theme

    let onSelect: (Verse) -> Void

    private var kept: [Verse] {
        library.verses.filter { bookmarks.contains($0.id) }
    }

    private var isDevanagari: Bool { settings.language == .sanskrit }

    var body: some View {
        VStack(spacing: 0) {
            header

            if kept.isEmpty {
                empty
            } else {
                list
            }
        }
        .background(theme.background)
    }

    private var header: some View {
        HStack {
            Text(isDevanagari ? "संगृहीत" : "BOOKMARKS")
                .font(isDevanagari ? .verseReference : .label)
                .tracking(isDevanagari ? 0 : 1.2)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            if !kept.isEmpty {
                Text(isDevanagari ? kept.count.devanagariDigits : "\(kept.count)")
                    .font(.label)
                    .foregroundStyle(theme.textSecondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.divider).frame(height: 1)
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.title3)
                .foregroundStyle(theme.textSecondary.opacity(0.6))
            Text("Tap the bookmark beside a verse number to keep it")
                .font(.label)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(kept) { verse in
                    Button { onSelect(verse) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verse.reference)
                                .font(.label)
                                .monospacedDigit()
                                .foregroundStyle(theme.accent)
                            Text(verse.displayLines(for: settings.language).first ?? verse.sanskrit)
                                .font(isDevanagari ? .glossDevanagari : .glossLatin)
                                .foregroundStyle(theme.textPrimary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bookmark-\(verse.reference)")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            bookmarks.toggle(verse.id)
                            Haptics.selection()
                        } label: {
                            Label("Remove", systemImage: "bookmark.slash")
                        }
                    }

                    Rectangle().fill(theme.divider).frame(height: 1)
                }
            }
        }
    }
}
