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

    @State private var confirmingReset = false

    private var isDevanagari: Bool { settings.language.isDevanagari }

    var body: some View {
        let snapshot = progress.snapshot

        return VStack(spacing: 0) {
            header

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

                    badges

                    resetControl(snapshot)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(theme.background)
    }

    // MARK: - Header

    private var header: some View {
        PanelHeader(sanskrit: "प्रगति", english: "PROGRESS", isDevanagari: isDevanagari)
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
            // Longest, not days read: alongside the current streak those two
            // show the same number for anyone who has not missed a day yet,
            // which reads as a mistake rather than as two facts.
            figure(
                value: snapshot.longestStreak,
                caption: isDevanagari ? "सर्वाधिक" : "best",
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
            Text(value.digits(devanagari: isDevanagari))
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

    // MARK: - Badges

    /// One heading per family, in catalogue order. No filter chips: with 35
    /// badges the whole set is a short scroll, and a control that hides most of
    /// them earns its place only when scrolling stops working.
    private var badges: some View {
        VStack(spacing: 20) {
            ForEach(Badge.Family.allCases, id: \.self) { family in
                let badges = BadgeCatalog.all(in: family)
                VStack(spacing: 12) {
                    section(
                        family.title(isDevanagari: isDevanagari),
                        count: (badges.count { progress.unlockedBadgeIDs.contains($0.id) }, badges.count)
                    )
                    BadgeGrid(
                        badges: badges,
                        earned: progress.unlockedBadgeIDs,
                        isDevanagari: isDevanagari
                    )
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Reset

    /// Last on the screen, so reaching it takes a deliberate scroll past
    /// everything it would destroy. Plain destructive text rather than a filled
    /// button: this is not an action to invite.
    private func resetControl(_ snapshot: ProgressSnapshot) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(theme.divider).frame(height: 1).padding(.vertical, 8)

            Button(role: .destructive) { confirmingReset = true } label: {
                Text(isDevanagari ? "प्रगति मिटाएँ" : "Reset progress")
                    .font(.label)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityIdentifier("resetProgress")
        }
        .padding(.top, 16)
        .confirmationDialog(
            isDevanagari ? "प्रगति मिटाएँ?" : "Reset progress?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button(isDevanagari ? "मिटाएँ" : "Reset", role: .destructive) {
                progress.reset()
                Haptics.selection()
            }
            Button(isDevanagari ? "रहने दें" : "Cancel", role: .cancel) {}
        } message: {
            // Naming what survives matters more than naming what goes: people
            // conflate bookmarks with progress, and the fear of losing forty
            // kept verses is what would stop them using this at all.
            Text(resetWarning(snapshot))
        }
    }

    private func resetWarning(_ snapshot: ProgressSnapshot) -> String {
        let earned = progress.unlockedBadgeIDs.count
        if isDevanagari {
            return """
                \(snapshot.versesRead.devanagariDigits) पढ़े हुए श्लोक, \(snapshot.currentStreak.devanagariDigits) दिन की निरंतरता और \(earned.devanagariDigits) उपलब्धियाँ मिट जाएँगी।
                आपके संगृहीत श्लोक और सेटिंग्स सुरक्षित रहेंगी।
                """
        }
        return """
            This erases \(snapshot.versesRead) verses read, a \(snapshot.currentStreak)-day streak and \(earned) badges.
            Your bookmarks and settings are not affected.
            """
    }

    // MARK: - Sections

    /// One heading, optionally with an "earned of total" beside it. These were
    /// two near-identical functions twenty lines apart, so the rule that
    /// letter-spacing must not apply to Devanagari was stated twice.
    @ViewBuilder
    private func section(_ title: String, count: (earned: Int, total: Int)? = nil) -> some View {
        HStack {
            Text(title)
                .font(.label)
                .tracking(isDevanagari ? 0 : 1.2)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            if let count {
                Text(Int.ratio(count.earned, of: count.total, devanagari: isDevanagari))
                    .font(.label)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
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
