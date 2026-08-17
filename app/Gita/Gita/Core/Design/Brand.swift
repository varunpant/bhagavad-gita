//
//  Brand.swift
//  Gita
//

import SwiftUI

/// The brand ramp: yellow at the top, through orange, to deep vermillion.
///
/// Defined once and used by the splash, the rail and the app icon, so the three
/// cannot drift apart. It is deliberately independent of `Theme` — the reading
/// surface stays plain in Light and Dark, and this is the colour that isn't.
///
/// The ground is yellow/orange the whole way down: no pink reaches the edge of
/// any surface. The one pink left in the brand is inside the mark itself, the
/// shadow under the ग.
///
/// The same values live in `tools/make_brand.py`, which renders the icon; change
/// them together.
nonisolated enum Brand {
    private static let yellow = Color(red: 0xFF / 255, green: 0xD2 / 255, blue: 0x4A / 255)
    private static let amber = Color(red: 0xFF / 255, green: 0xA2 / 255, blue: 0x1C / 255)
    private static let orange = Color(red: 0xFF / 255, green: 0x6F / 255, blue: 0x17 / 255)
    private static let vermillion = Color(red: 0xE8 / 255, green: 0x45 / 255, blue: 0x1E / 255)

    /// The ramp itself, warm end first. Exposed because the widgets sweep it
    /// around a ring and along a bar chart, neither of which is a top-to-bottom
    /// linear fill — and reaching for the raw hexes there would be exactly the
    /// drift this type exists to prevent.
    static let ramp: [Color] = [yellow, amber, orange, vermillion]

    /// Top to bottom, for full-height surfaces: the splash and the rail.
    static var gradient: LinearGradient {
        LinearGradient(colors: ramp, startPoint: .top, endPoint: .bottom)
    }

    /// The ramp swept around a circle, for progress rings. Stops short of a full
    /// turn and mirrors back so the two ends meet in the same yellow instead of
    /// showing a seam where vermillion butts into it.
    /// No rotation here: the ring view already turns its stroke so the arc
    /// starts at twelve o'clock, and the gradient turns with it. Rotating both
    /// put the vermillion end at the top and started the ring on its last
    /// colour.
    static var ring: AngularGradient {
        AngularGradient(colors: ramp + ramp.reversed(), center: .center)
    }
}
