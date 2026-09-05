//
//  ReadingTracker.swift
//  Gita
//

import Foundation
import SwiftUI

/// Decides whether a verse currently on screen should count as read.
///
/// Split out as a pure function so the policy — the part with the judgement in
/// it — can be unit tested, leaving only the sleep untested.
nonisolated enum ReadingPolicy {

    /// What the app is doing while a verse sits on screen.
    struct Conditions: Equatable, Sendable {
        var isActive: Bool
        /// Rail, panel or search — `Drawer.isCoveringReader`. One flag, because
        /// the three were only ever tested together.
        var isCovered: Bool
        var alreadyRead: Bool
    }

    /// A verse counts only when it is the thing being looked at.
    ///
    /// - Backgrounded: a verse left on screen overnight must not count when the
    ///   phone is next picked up.
    /// - Covered: the verse is behind the rail, a panel or search, and browsing
    ///   the contents is not reading.
    /// - Already read: nothing to gain, and re-recording would need a second
    ///   write on every page turn through familiar ground.
    static func shouldCount(_ conditions: Conditions) -> Bool {
        conditions.isActive && !conditions.isCovered && !conditions.alreadyRead
    }

    /// How long a verse must stay on screen. Long enough that flicking through
    /// thirty verses to reach 12.13 records none of them; short enough that
    /// actually reading one always does.
    static let dwell = Duration.seconds(3)

    /// The same number, in words, for the screens that explain the rule.
    ///
    /// `HelpView` said "three seconds" and "तीन सेकंड" in prose. Changing the
    /// policy made the help screen lie, in two scripts, with nothing failing.
    static func dwellSeconds(isDevanagari: Bool) -> String {
        let seconds = dwell.components.seconds
        guard isDevanagari else { return "\(seconds)" }
        return Int(seconds).devanagariDigits
    }
}

/// Watches the reader and records what has been read.
///
/// A view modifier rather than a view: it has no appearance, and attaching it
/// to the reader keeps the timer's lifetime tied to the reader's.
struct ReadingTrackerModifier: ViewModifier {
    let verseID: Int?

    @Environment(ReadingProgress.self) private var progress
    @Environment(ReadingDwell.self) private var dwell
    @Environment(Drawer.self) private var drawer
    @Environment(\.scenePhase) private var scenePhase

    private var conditions: ReadingPolicy.Conditions {
        ReadingPolicy.Conditions(
            isActive: scenePhase == .active,
            isCovered: drawer.isCoveringReader,
            alreadyRead: verseID.map { progress.hasRead($0) } ?? true
        )
    }

    func body(content: Content) -> some View {
        content
            // Keyed on everything the policy reads, so opening the rail or
            // backgrounding the app cancels the pending dwell rather than
            // letting it fire behind a panel. `.task(id:)` restarts on any
            // change and cancels the old one for free — no timer to invalidate,
            // nothing to clean up, and it dies with the view.
            .task(id: TrackedState(verseID: verseID, conditions: conditions)) {
                guard let verseID, ReadingPolicy.shouldCount(conditions) else {
                    dwell.cancel()
                    return
                }

                // The meter in the header draws from this, so it starts when
                // the sleep starts and stops when the sleep is cancelled —
                // which is the whole point of it being one state rather than
                // two three-second animations that happen to agree.
                dwell.begin()

                try? await Task.sleep(for: ReadingPolicy.dwell)
                guard !Task.isCancelled else {
                    dwell.cancel()
                    return
                }

                progress.record(verseID)
                dwell.complete()
            }
    }

    /// One value so `.task(id:)` restarts on any of them.
    private struct TrackedState: Equatable {
        let verseID: Int?
        let conditions: ReadingPolicy.Conditions
    }
}

extension View {
    /// Counts the given verse as read once it has been on screen long enough.
    func tracksReading(of verseID: Int?) -> some View {
        modifier(ReadingTrackerModifier(verseID: verseID))
    }
}
