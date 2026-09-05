//
//  WidgetProgressPublisher.swift
//  Gita
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Keeps the App Group's progress file in step with the app, and asks WidgetKit
/// to redraw when it changes.
///
/// Attached once, at the root. Data flows app → container → widget and never
/// back, so this is the only place that writes: a widget can no more ask for a
/// count than it can ask for a verse.
///
/// It publishes on four things, which between them cover every way the file can
/// go stale — a verse read, a day rolled over into a new streak, the reading
/// language switched, the theme switched. The last two matter because the
/// widget draws in the reader's script and the reader's theme.
private struct WidgetProgressPublisher: ViewModifier {
    @Environment(ReadingProgress.self) private var progress
    @Environment(Settings.self) private var settings
    @Environment(Library.self) private var library

    /// The four inputs as one value.
    ///
    /// They were four separate `onChange` handlers, which meant four separate
    /// calls to `publish()` — and `publish()` takes a `ProgressSnapshot`, which
    /// walks every read verse and recomputes both streaks. On a cold launch at
    /// least two of them fire in the same update, the read count with
    /// `initial: true` and the corpus becoming ready, so the app opened by
    /// building the same snapshot twice and writing the same file twice.
    private struct Inputs: Equatable {
        let versesRead: Int
        let isReady: Bool
        let language: ReadingLanguage
        let theme: ThemePreference
    }

    private var inputs: Inputs {
        Inputs(versesRead: progress.readVerseIDs.count,
               isReady: library.state.isReady,
               language: settings.language,
               theme: settings.theme)
    }

    func body(content: Content) -> some View {
        // `task(id:)` rather than four `onChange`s: it runs once on appear —
        // which is what `initial: true` was for — and once per *distinct*
        // combination after that, so changes landing in the same update
        // coalesce into a single write instead of racing each other to it.
        content.task(id: inputs) { publish() }
    }

    private func publish() {
        let snapshot = progress.snapshot
        let shared = SharedProgress(
            versesRead: snapshot.versesRead,
            // Before the corpus loads the total is zero, and a ring against
            // zero is meaningless. Keeping the last shared total in that case
            // is what stops the widget flickering to "0 of 0" on a cold launch.
            totalVerses: snapshot.totalVerses > 0
                ? snapshot.totalVerses
                : (SharedProgressStore.read()?.totalVerses ?? 0),
            currentStreak: snapshot.currentStreak,
            longestStreak: snapshot.longestStreak,
            dayCounts: recentCounts(),
            isDevanagari: settings.language.isDevanagari,
            theme: settings.theme.rawValue,
            updatedAt: Date()
        )

        guard SharedProgressStore.write(shared) else { return }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// The last thirty days. The whole history would grow without bound in a
    /// file that exists to draw seven bars.
    private func recentCounts() -> [String: Int] {
        let horizon = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let cutoff = horizon.map(SharedProgress.day(for:)) ?? ""
        return progress.readingDayCounts.filter { $0.key >= cutoff }
    }
}

extension View {
    /// Attach once, at the root.
    func publishesProgressToWidgets() -> some View {
        modifier(WidgetProgressPublisher())
    }
}
