//
//  Brand.swift
//  Gita
//

import SwiftUI

/// The brand ramp: yellow at the top, through orange, to bright pink.
///
/// Defined once and used by the splash, the rail and the app icon, so the three
/// cannot drift apart. It is deliberately independent of `Theme` — the reading
/// surface stays plain in Light and Dark, and this is the colour that isn't.
///
/// The same values live in `tools/make_brand.py`, which renders the icon; change
/// them together.
nonisolated enum Brand {
    static let yellow = Color(red: 0xFF / 255, green: 0xC9 / 255, blue: 0x3C / 255)
    static let orange = Color(red: 0xFF / 255, green: 0x7A / 255, blue: 0x18 / 255)
    static let pink = Color(red: 0xFF / 255, green: 0x2D / 255, blue: 0x78 / 255)

    /// Top to bottom, for full-height surfaces: the splash and the rail.
    static var gradient: LinearGradient {
        LinearGradient(colors: [yellow, orange, pink], startPoint: .top, endPoint: .bottom)
    }
}
