//
//  TableOfContentsView.swift
//  Gita
//

import SwiftUI

/// The eighteen chapters, and a way to reach any verse.
///
/// Opened from the rail. The header is `PanelHeader` — the title, a two-swatch
/// legend for what the chips' fill and edge mean, and the way out — and
/// everything below it is content. Searching lives in its own overlay, not
/// here; this panel is for browsing the book's own order.
struct TableOfContentsView: View {
    @Environment(Library.self) private var library
    @Environment(Settings.self) private var settings
    @Environment(ReadingProgress.self) private var progress
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Where the reader currently is, so the list can open there.
    let currentVerse: Verse?
    /// Called with the chosen verse; the sheet dismisses itself.
    let onSelect: (Verse) -> Void
    /// How to close when shown as a panel, where `dismiss` means nothing.
    var onClose: (() -> Void)?

    @State private var expandedChapter: Int?

    /// The contents follow the reading language, like every other surface — see
    /// the language rules in `app/CLAUDE.md`. They used to carry a switcher of
    /// their own, with a local copy of the language that browsing changed and
    /// closing threw away. Two controls for one setting is one too many: the
    /// rail's switcher is the language of the whole reading surface, and this
    /// panel is part of it.
    private var isDevanagari: Bool { settings.language.isDevanagari }

    var body: some View {
        VStack(spacing: 0) {
            header

            chapterList(progress.snapshot)
        }
        .background(theme.background)
        .tint(theme.accent)
        .onAppear { expandedChapter = currentVerse?.chapter }
        // The corpus loads asynchronously, and `currentVerse` is looked up in
        // it — so on a cold launch straight into this panel there is no current
        // verse yet when `onAppear` runs, and the reader is shown eighteen
        // closed chapters with no sign of where they are. This fills that in
        // the moment the lookup succeeds.
        //
        // Guarded on `nil` so it only ever fills a blank: once a chapter is
        // open, it is the reader's, and moving through the book must not
        // reach in and reopen something they closed.
        .onChange(of: currentVerse?.chapter) { _, chapter in
            guard expandedChapter == nil, let chapter else { return }
            expandedChapter = chapter
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 520, idealHeight: 640)
        #endif
    }

    // MARK: - Header

    private var header: some View {
        // The cross is no longer conditional. It used to appear only when the
        // contents were a sheet, because as a panel the rail's icon became the
        // cross instead — which put the way out on the far edge of the screen.
        PanelHeader(
            sanskrit: "अध्याय", english: "CHAPTERS", isDevanagari: isDevanagari,
            closeLabel: "Close contents", onClose: close
        ) {
            legend
        }
    }

    /// What the two marks on a chip mean, in the space `PanelHeader` keeps
    /// between the title and the way out.
    ///
    /// Two swatches, no words. The grid teaches the rest by itself — a numeral
    /// is a verse, a tap opens it — but nothing on the panel says why four
    /// numbers in a chapter wear a gold edge, and the ring is a claim about the
    /// verse rather than about the reader, which is not guessable. The read
    /// disc sits beside it because the two are easy to confuse: one is the
    /// fill, the other the edge.
    ///
    /// Drawn from `fill` and `ring` rather than restated, so a legend cannot
    /// come to describe a chip the app no longer draws.
    private var legend: some View {
        HStack(spacing: 10) {
            swatch(isRead: true, isFamous: false,
                   label: isDevanagari ? "पढ़ा" : "Read")
            swatch(isRead: false, isFamous: true,
                   label: isDevanagari ? "प्रसिद्ध" : "Famous")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Key: filled is read, gold edge is a famous verse")
    }

    private func swatch(isRead: Bool, isFamous: Bool, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(fill(isCurrent: false, isRead: isRead))
                .overlay { ring(isCurrent: false, isFamous: isFamous) }
                .frame(width: 12, height: 12)

            Text(label)
                .font(isDevanagari ? .labelDevanagari : .label)
                .tracking(isDevanagari ? 0 : 0.6)
                .foregroundStyle(theme.textSecondary)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Chapters

    private func chapterList(_ snapshot: ProgressSnapshot) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(library.chapters) { chapter in
                        chapterRow(chapter, snapshot: snapshot)
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

    private func chapterRow(_ chapter: Chapter, snapshot: ProgressSnapshot) -> some View {
        let isOpen = expandedChapter == chapter.id
        // Open or current, either way the disc is filled and the numeral is
        // drawn in the ink that goes on a filled disc.
        let isFilled = isOpen || isCurrent(chapter)

        return Button {
            // Opening a chapter is the one move in the contents that changes
            // the panel without leaving it. Choosing a verse needs nothing
            // here: it moves the reader, and the page turn speaks for it.
            Haptics.selection()
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
                    .foregroundStyle(isFilled ? theme.onSelection : theme.accent)
                    .frame(width: 34, height: 34)
                    .background { numeralDisc(isOpen: isOpen, chapter: chapter) }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isDevanagari ? chapter.nameSa : chapter.nameEn)
                        .font(isDevanagari ? .wordDevanagari : .wordLatin)
                        .foregroundStyle(theme.textPrimary)
                        // Two lines where the name needs them, and no reserved
                        // space: reserving it left the numeral centred against
                        // an empty line, floating between the name and the
                        // count.
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    // The count, in the same script as the name above it. The
                    // other language's title underneath read as a mistake:
                    // Devanagari heading, English subheading, on every row.
                    Text(isDevanagari
                         ? "\(chapter.verseCount.devanagariDigits) श्लोक"
                         : "\(chapter.verseCount) verses")
                        .font(isDevanagari ? .labelDevanagari : .label)
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                // How much of the chapter has been read, in the same grey as
                // the chips inside it — so the row answers the question without
                // being opened. A finished chapter gets a tick instead of a
                // count: "47 of 47" is a number to check, a tick is not.
                readMarker(for: chapter, in: snapshot)

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
        .accessibilityValue("\(snapshot.versesRead(inChapter: chapter.id)) read")
    }

    /// The chapter numeral's disc.
    ///
    /// Two filled states, and the open one wins where they coincide. The
    /// **open** accordion takes the theme's selection gradient, which is the
    /// only gradient on the panel and marks the one chapter the reader is
    /// looking into. The chapter they are reading *in* keeps the flat tint, so
    /// the two are still tellable apart when they are different chapters.
    ///
    /// The gradient comes from `Theme`, not from `Brand`, which is what makes
    /// this honour the theme: Light sweeps its yellow, Dark its deep orange,
    /// and Sepia shifts weight without introducing a second hue. Sweeping the
    /// whole ramp in every theme would put white numerals on yellow in Dark.
    @ViewBuilder
    private func numeralDisc(isOpen: Bool, chapter: Chapter) -> some View {
        if isOpen {
            Circle().fill(theme.selectionGradient)
        } else {
            Circle()
                .fill(isCurrent(chapter) ? theme.selectionTint : .clear)
                .overlay(Circle().stroke(theme.accent.opacity(0.35), lineWidth: 1))
        }
    }

    /// Grey throughout, and absent entirely until something has been read in
    /// that chapter — eighteen "0" markers on a first launch would be a wall of
    /// zeroes telling a new reader they have failed at nothing.
    @ViewBuilder
    private func readMarker(for chapter: Chapter, in snapshot: ProgressSnapshot) -> some View {
        let read = snapshot.versesRead(inChapter: chapter.id)

        if read >= chapter.verseCount, chapter.verseCount > 0 {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary.opacity(0.7))
                .accessibilityHidden(true)
        } else if read > 0 {
            Text(Int.ratio(read, of: chapter.verseCount, devanagari: isDevanagari))
                .font(isDevanagari ? .labelDevanagari : .label)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary.opacity(0.7))
                .accessibilityHidden(true)
        }
    }

    /// Verse numbers as a grid of chips — compact enough that even chapter 18's
    /// 78 verses stay reachable without a long scroll.
    ///
    /// A read verse wears a light grey disc. Three states have to stay apart at
    /// a glance and at chip size: where the reader is now (accent, filled),
    /// where they have been (grey, filled) and where they have not (outline
    /// only). Grey rather than a tint, because the accent is monochrome in
    /// every theme but Sepia — a coloured "read" marker would be the only
    /// colour on the panel.
    ///
    /// A well-known verse wears a marigold ring where the others have a grey
    /// one. That is deliberately a different channel from the three states
    /// above — fill for progress, edge for the text itself — because fame is a
    /// property of the verse and progress is a property of the reader, so the
    /// two have to be readable at once and must never be mistaken for each
    /// other. See `FamousVerses`.
    private func verseGrid(for chapter: Chapter) -> some View {
        let verses = library.verses(inChapter: chapter.id)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 10)], spacing: 10) {
            ForEach(verses) { verse in
                chip(verse)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func chip(_ verse: Verse) -> some View {
        let isCurrent = verse.id == currentVerse?.id
        let isRead = progress.hasRead(verse.id)
        let isFamous = verse.isFamous

        return Button {
            choose(verse)
        } label: {
            // The gloss pair rather than the label pair: both scripts at
            // the same size, which is what keeps a grid of fixed
            // circles looking like one grid in either language.
            Text(verse.sutra.digits(devanagari: isDevanagari))
                .font(isDevanagari ? .glossDevanagari : .glossLatin)
                .monospacedDigit()
                .foregroundStyle(isCurrent ? theme.onSelection : theme.textPrimary)
                // Circles, like the chapter numerals: the two lists sit
                // one inside the other and should read as one family.
                .frame(width: 38, height: 38)
                .background {
                    Circle()
                        .fill(fill(isCurrent: isCurrent, isRead: isRead))
                        .overlay { ring(isCurrent: isCurrent, isFamous: isFamous) }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Marking by hand, for the verse someone has read elsewhere or sat with
        // for an hour without the reader on screen. Reading still marks itself
        // — this is the deliberate version of the same act, and like everything
        // else it counts towards chapters, streaks and goals.
        //
        // There is no "mark as unread": progress is never revoked one verse at
        // a time, only wholesale by Reset in the Progress panel.
        .contextMenu {
            if !isRead {
                Button {
                    Haptics.selection()
                    progress.record(verse.id)
                } label: {
                    Label(
                        isDevanagari ? "पढ़ा हुआ चिह्नित करें" : "Mark as read",
                        systemImage: "checkmark.circle"
                    )
                }
            }
        }
        .accessibilityLabel("Verse \(verse.chapter).\(verse.sutra)")
        // Two facts, and VoiceOver gets both — the marker is not decoration,
        // and a reader who cannot see it should still be told which verses the
        // world quotes.
        .accessibilityValue(isFamous
                            ? (isRead ? "Read, well known" : "Not read, well known")
                            : (isRead ? "Read" : "Not read"))
        .accessibilityIdentifier("verse-\(verse.chapter).\(verse.sutra)")
    }

    /// The chip's edge, which is where being well known is said.
    ///
    /// The **border**, not a mark added beside it: the three progress states
    /// live in the disc's *fill* — accent filled, grey filled, empty — so the
    /// edge is free to carry something else entirely, and a verse can be read
    /// and famous, or unread and famous, with both facts legible at once. An
    /// earlier version drew a small rule under the chip instead; a ring is the
    /// same information without adding a second object to a grid of 78.
    ///
    /// The ramp is the one deliberate exception to this panel's monochrome.
    /// The rule against colour here is about *progress* markers — a coloured
    /// "read" would be the only colour on the panel and would read as a reward.
    /// This is furniture: an editorial note about the text, in the colour the
    /// app uses for furniture everywhere else.
    ///
    /// Where the reader is now takes precedence and wears no ring at all: that
    /// chip is filled with the selection tint, and a marigold ring around a
    /// marigold disc says nothing.
    @ViewBuilder
    private func ring(isCurrent: Bool, isFamous: Bool) -> some View {
        if isCurrent {
            EmptyView()
        } else if isFamous {
            // `strokeBorder`, not `stroke` — a stroke straddles the path and
            // would spill half its width outside the 38pt chip, which at
            // 1.5pt is enough to crowd its neighbours in the grid.
            Circle().strokeBorder(
                LinearGradient(colors: Brand.ramp,
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1.5
            )
        } else {
            Circle().strokeBorder(theme.divider, lineWidth: 1)
        }
    }

    private func fill(isCurrent: Bool, isRead: Bool) -> Color {
        if isCurrent { return theme.selectionTint }
        // Light enough to sit under the numeral without fighting it, and the
        // same grey in all four themes because `divider` already resolves per
        // theme.
        return isRead ? theme.divider.opacity(0.9) : .clear
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
        .environment(ReadingProgress())
        .environment(\.theme, .light)
}
