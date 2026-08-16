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
    @Environment(Settings.self) private var settings
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Where the reader currently is, so the list can open there.
    let currentVerse: Verse?
    /// Called with the chosen verse; the sheet dismisses itself.
    let onSelect: (Verse) -> Void
    /// How to close when shown as a panel, where `dismiss` means nothing.
    var onClose: (() -> Void)?

    @State private var expandedChapter: Int?

    /// Seeded from the reader's language when the sheet opens, then owned by
    /// the sheet. Browsing the contents in English while reading in Sanskrit is
    /// a reasonable thing to want, and it should not change what the reader
    /// shows when the sheet closes.
    @State private var language: ReadingLanguage = .sanskrit

    private var isDevanagari: Bool { language == .sanskrit }

    var body: some View {
        VStack(spacing: 0) {
            header

            chapterList
        }
        .background(theme.background)
        .tint(theme.accent)
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
            Text(isDevanagari ? "अध्याय" : "CHAPTERS")
                .font(isDevanagari ? .verseReference : .label)
                .tracking(isDevanagari ? 0 : 1.2)
                .foregroundStyle(theme.textSecondary)
            Spacer()

            languageToggle

            // Rightmost, and the only xmark in the sheet: on Mac this is the
            // sole way out, as a sheet there has no swipe-to-dismiss.
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .regular))
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .accessibilityIdentifier("tocClose")
            .accessibilityLabel("Close contents")
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
                .font(.system(size: 17, weight: .medium))
                .frame(width: 32, height: 32)
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

    // MARK: - Actions

    private func isCurrent(_ chapter: Chapter) -> Bool {
        currentVerse?.chapter == chapter.id
    }

    private func choose(_ verse: Verse) {
        onSelect(verse)
        close()
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}

#Preview {
    TableOfContentsView(currentVerse: nil) { _ in }
        .environment(Library.preview())
        .environment(Settings())
        .environment(\.theme, .light)
}
