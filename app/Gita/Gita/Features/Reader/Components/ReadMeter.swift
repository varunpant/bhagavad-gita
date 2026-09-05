//
//  ReadMeter.swift
//  Gita
//

import SwiftUI

/// A small ring beside the bookmark that closes as the verse is being read,
/// ticks when it counts, and leaves the tick behind.
///
/// The rule it draws is `ReadingPolicy`: three seconds on screen, uncovered and
/// in the foreground, and the verse is marked. That was invisible — a mark
/// appearing in the contents later looked arbitrary, and someone who swiped on
/// at two seconds never learned why that verse did not count. Now the page says
/// so while it happens.
///
/// **Outline only, and small.** This sits on the reading surface, where the one
/// thing that should hold the eye is the verse. A filled disc or anything
/// larger would be a second thing to watch; a thin ring at the edge of vision
/// is noticed when looked at and ignored when not.
///
/// It draws `ReadingDwell` rather than timing anything itself — see that type
/// for why the timing lives in one place.
struct ReadMeter: View {
    /// Whether the verse on screen has already been read.
    ///
    /// The meter is not only about the moment of counting: a verse that was
    /// read last week should say so while it is open, in the same place, or
    /// the reader has to open the contents to find out. The ring earns the
    /// tick; the tick then stays.
    let isRead: Bool

    @Environment(ReadingDwell.self) private var dwell
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Matched to the bookmark glyph beside it rather than to the tap target:
    /// the two read as a pair on the same line, and 17pt is the glyph's size.
    private let size: CGFloat = 15

    /// Sweep to full, then hold the tick long enough to be seen at a glance
    /// without becoming something to wait for.
    private static let tick = Duration.milliseconds(900)

    @State private var sweep: CGFloat = 0

    /// Whether a tick is on screen — just earned, or standing from a previous
    /// reading. Either way the page is saying "this one counts".
    private var showsTick: Bool {
        if case .marked = dwell.phase { return true }
        if case .idle = dwell.phase { return isRead }
        return false
    }

    var body: some View {
        ZStack {
            switch dwell.phase {
            case .idle:
                // Standing state, and quieter than the one that celebrates:
                // grey like the rest of the page's furniture rather than the
                // brand. Being read is a fact about the verse, not an event —
                // the brand belongs to the moment it happened.
                if isRead {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textSecondary.opacity(0.55))
                        .frame(width: size, height: size)
                        .transition(.opacity)
                }

            case .counting:
                Circle()
                    .trim(from: 0, to: sweep)
                    .stroke(
                        // The ramp swept round, so the ring is the brand rather
                        // than a yellow — the same choice the kept bookmark and
                        // the progress ring make.
                        AngularGradient(colors: Brand.ramp + [Brand.ramp[0]],
                                        center: .center),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                    )
                    // Twelve o'clock, clockwise. A ring that starts at three is
                    // read as a fragment rather than as a beginning.
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)

            case .marked:
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Brand.gradient)
                    .frame(width: size, height: size)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: dwell.phase)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: isRead)
        // The sweep is the dwell, so it is keyed on the same phase the tracker
        // sets. Reduce Motion gets the closed ring without the travel: the
        // information is "this is counting", not the motion itself.
        .task(id: dwell.phase) {
            switch dwell.phase {
            case .counting:
                sweep = 0
                if reduceMotion {
                    sweep = 1
                } else {
                    withAnimation(.linear(duration: ReadingPolicy.dwell.seconds)) {
                        sweep = 1
                    }
                }
            case .marked:
                sweep = 0
                try? await Task.sleep(for: Self.tick)
                guard !Task.isCancelled else { return }
                dwell.clear()
            case .idle:
                sweep = 0
            }
        }
        // The tick is worth announcing and the ring is not.
        //
        // "Read" is a fact about the verse on screen, and a reader who cannot
        // see the mark would otherwise have to open the contents to learn it.
        // The three-second sweep is the opposite: a countdown narrated on every
        // page turn is noise, and it says nothing that has happened yet.
        //
        // The identifier rides on the same element, which is what lets
        // `ReaderUITests` check the tick is there at all — hidden from the
        // accessibility tree, it was invisible to the tests too.
        .accessibilityElement()
        .accessibilityHidden(!showsTick)
        .accessibilityLabel("Read")
        .accessibilityIdentifier(showsTick ? "readTick" : "readMeter")
    }
}

private extension Duration {
    /// The whole seconds and the fraction, as an animation wants them.
    var seconds: Double {
        let (whole, attoseconds) = components
        return Double(whole) + Double(attoseconds) / 1e18
    }
}
