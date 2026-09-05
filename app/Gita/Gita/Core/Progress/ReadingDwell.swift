//
//  ReadingDwell.swift
//  Gita
//

import Observation
import SwiftUI

/// What the reader is doing towards marking the verse in front of them.
///
/// The rule has always been invisible: a verse counts once it has been on
/// screen, uncovered, for `ReadingPolicy.dwell`. Nothing said so, so a mark
/// appearing in the contents later looked arbitrary — and a reader who swiped
/// away at two and a half seconds never learned why that one did not count.
///
/// One source of truth, deliberately: `ReadingTrackerModifier` owns the timing
/// and writes here, and the meter in the reader's header only draws what it
/// finds. A meter that ran its own three-second animation beside a tracker
/// running its own three-second sleep would agree only by luck, and disagree
/// the moment the rail opened.
@Observable
final class ReadingDwell {

    /// No associated verse id: the meter draws the same ring whichever verse
    /// is being counted, and the tracker restarts the phase on every change of
    /// verse anyway. An id here was a payload every `case` had to ignore.
    enum Phase: Equatable {
        /// Nothing to show: already read, covered, or backgrounded.
        case idle
        /// Counting down on the verse in front of the reader. The meter sweeps.
        case counting
        /// Just recorded. The meter shows a tick, then leaves.
        case marked
    }

    private(set) var phase: Phase = .idle

    func begin() {
        phase = .counting
    }

    /// The dwell was interrupted — the rail opened, the app went away, or the
    /// reader turned the page. No mark, and no tick.
    func cancel() {
        if case .marked = phase { return }   // let a tick finish being seen
        phase = .idle
    }

    func complete() {
        phase = .marked
    }

    /// The tick has been seen. Called by the meter rather than on a second
    /// timer here, so the state leaves exactly when the animation ends.
    func clear() {
        if case .marked = phase { phase = .idle }
    }
}
