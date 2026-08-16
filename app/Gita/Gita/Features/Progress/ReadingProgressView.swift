//
//  ReadingProgressView.swift
//  Gita
//

import SwiftUI

/// How far through the Gita the reader has got.
///
/// Not `ProgressView` — that is a SwiftUI type, and shadowing it would turn
/// every spinner in this module into this panel.
///
/// One scrolling column rather than RigVeda's Activity/Metrics/Achievements
/// tabs: this book has one number that matters and enough room to show it,
/// and a segmented control would hide two-thirds of the screen.
struct ReadingProgressView: View {
    @Environment(Library.self) private var library
    @Environment(ReadingProgress.self) private var progress
    @Environment(Settings.self) private var settings
    @Environment(\.theme) private var theme

    /// Moves the reader to the first verse of a chapter.
    let onSelect: (Verse) -> Void

    private var isDevanagari: Bool { settings.language == .sanskrit }

    var body: some View {
        let snapshot = progress.snapshot

        return VStack(spacing: 0) {
            header(snapshot)

            ScrollView {
                VStack(spacing: 24) {
                    CompletionRing(
                        completion: snapshot.completion,
                        versesRead: snapshot.versesRead,
                        totalVerses: snapshot.totalVerses,
                        isDevanagari: isDevanagari
                    )

                    figures(snapshot)

                    section(isDevanagari ? "अध्याय" : "CHAPTERS")

                    ChapterProgressList(
                        chapters: library.chapters,
                        snapshot: snapshot,
                        isDevanagari: isDevanagari,
                        onSelect: open
                    )
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(theme.background)
    }

    // MARK: - Header

    private func header(_ snapshot: ProgressSnapshot) -> some View {
        HStack {
            Text(isDevanagari ? "प्रगति" : "PROGRESS")
                .font(isDevanagari ? .verseReference : .label)
                .tracking(isDevanagari ? 0 : 1.2)
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.divider).frame(height: 1)
        }
    }

    // MARK: - Figures

    /// Three numbers, evenly divided. Verses read is the same number as the
    /// ring's, spelled out — the ring gives the shape, this gives the count.
    private func figures(_ snapshot: ProgressSnapshot) -> some View {
        HStack(spacing: 0) {
            figure(
                value: snapshot.versesRead,
                caption: isDevanagari ? "श्लोक" : "read",
                symbol: nil
            )
            divider
            figure(
                value: snapshot.currentStreak,
                caption: isDevanagari ? "दिन" : "streak",
                symbol: "flame"
            )
            divider
            figure(
                value: snapshot.daysRead,
                caption: isDevanagari ? "कुल दिन" : "days",
                symbol: nil
            )
        }
        .padding(.horizontal, 16)
    }

    private var divider: some View {
        Rectangle().fill(theme.divider).frame(width: 1, height: 34)
    }

    private func figure(value: Int, caption: String, symbol: String?) -> some View {
        VStack(spacing: 3) {
            Text(isDevanagari ? value.devanagariDigits : "\(value)")
                .font(.system(size: 24, weight: .light))
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)

            HStack(spacing: 3) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10))
                }
                Text(caption)
                    .font(.label)
            }
            .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sections

    private func section(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.label)
                .tracking(isDevanagari ? 0 : 1.2)
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Navigation

    /// Opens a chapter at its first verse. Guarded rather than force-unwrapped:
    /// the corpus can still be loading when the panel is opened from a launch
    /// argument.
    private func open(_ chapter: Chapter) {
        guard let first = library.verses(inChapter: chapter.id).first else { return }
        onSelect(first)
    }
}
