//
//  ChapterProgressList.swift
//  Gita
//

import SwiftUI

/// One card per chapter: its name, how far through it the reader is, and a bar.
///
/// The only view in the app that shows the Gita whole with your place in it —
/// which is why tapping a card moves the reader there rather than just sitting
/// as a statistic. Progress is a navigation surface, not a trophy cabinet.
///
/// Two across on a phone, three on an iPad or a Mac, from `PanelColumns` — the
/// same rule the goals above them follow. As full-width rows the numbers were
/// the problem: the chapter number was a column of its own on the left, the
/// count another on the right, and a name between them that is one line in
/// Devanagari and two or three in English. The numbers ended up floating
/// against whatever height the name happened to take. On a card there is one
/// column: the number at the top, the name under it, the bar and the count at
/// the foot, all left-aligned to the same edge.
struct ChapterProgressList: View {
    let chapters: [Chapter]
    let snapshot: ProgressSnapshot
    let isDevanagari: Bool
    let onSelect: (Chapter) -> Void

    @Environment(\.theme) private var theme
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var columns: [GridItem] {
        #if os(iOS)
        let count = PanelColumns.cards.count(for: sizeClass)
        #else
        let count = PanelColumns.cards.count
        #endif
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(chapters) { chapter in
                Button { onSelect(chapter) } label: { card(chapter) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("progress-chapter-\(chapter.id)")
            }
        }
        .padding(.horizontal, 16)
    }

    private func card(_ chapter: Chapter) -> some View {
        let read = snapshot.versesRead(inChapter: chapter.id)
        let complete = snapshot.isComplete(chapter: chapter.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(chapter.id.digits(devanagari: isDevanagari))
                    .font(isDevanagari ? .labelDevanagari : .label)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)

                Spacer(minLength: 0)

                // A finished chapter is worth marking, and a checkmark says it
                // without needing a colour the theme rule would forbid.
                if complete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
            }

            Text(isDevanagari ? chapter.nameSa : chapter.nameEn)
                .font(isDevanagari ? .glossDevanagari : .glossLatin)
                .foregroundStyle(theme.textPrimary)
                // Three lines and a little shrink rather than two lines
                // reserved: at a card's width "Knowledge and the Renunciation of
                // Action" wants three, and reserving them would leave two empty
                // lines under every Devanagari name, which are single compounds.
                // Cards in a row match each other by stretching instead.
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            ProgressBar(fraction: snapshot.completion(ofChapter: chapter.id))

            Text(Int.ratio(read, of: chapter.verseCount, devanagari: isDevanagari))
                .font(isDevanagari ? .labelDevanagari : .label)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
        }
        .padding(12)
        // The bar and the count sit at the foot of every card in a row, however
        // long the name above them — siblings stretch to the tallest.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.divider, lineWidth: 1)
                }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Chapter \(chapter.id), \(chapter.nameEn), \(read) of \(chapter.verseCount) read"
        )
    }
}
