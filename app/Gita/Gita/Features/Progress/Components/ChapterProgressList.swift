//
//  ChapterProgressList.swift
//  Gita
//

import SwiftUI

/// One row per chapter: its name, how far through it the reader is, and a bar.
///
/// The only view in the app that shows the Gita whole with your place in it —
/// which is why tapping a row moves the reader there rather than just sitting
/// as a statistic. Progress is a navigation surface, not a trophy cabinet.
struct ChapterProgressList: View {
    let chapters: [Chapter]
    let snapshot: ProgressSnapshot
    let isDevanagari: Bool
    let onSelect: (Chapter) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(chapters) { chapter in
                Button { onSelect(chapter) } label: { row(chapter) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("progress-chapter-\(chapter.id)")

                Rectangle().fill(theme.divider).frame(height: 1)
            }
        }
    }

    private func row(_ chapter: Chapter) -> some View {
        let read = snapshot.versesRead(inChapter: chapter.id)
        let complete = snapshot.isComplete(chapter: chapter.id)

        return HStack(alignment: .center, spacing: 12) {
            Text(isDevanagari ? chapter.devanagariNumber : "\(chapter.id)")
                .font(.label)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(isDevanagari ? chapter.nameSa : chapter.nameEn)
                        .font(isDevanagari ? .glossDevanagari : .glossLatin)
                        .foregroundStyle(theme.textPrimary)
                        // Two lines, not one: "Knowledge and the Renunciation
                        // of Action" truncates mid-word at this width, and a
                        // chapter's name is the thing the row is about.
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // A finished chapter is worth marking, and a checkmark says
                    // it without needing a colour the theme rule would forbid.
                    if complete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                }

                ProgressBar(fraction: fraction(read: read, total: chapter.verseCount))
            }

            Text(counts(read: read, total: chapter.verseCount))
                .font(.label)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Chapter \(chapter.id), \(chapter.nameEn), \(read) of \(chapter.verseCount) read"
        )
    }

    private func fraction(read: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(read) / Double(total)
    }

    private func counts(read: Int, total: Int) -> String {
        isDevanagari
            ? "\(read.devanagariDigits)/\(total.devanagariDigits)"
            : "\(read)/\(total)"
    }
}
