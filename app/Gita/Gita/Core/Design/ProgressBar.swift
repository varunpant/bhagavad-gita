//
//  ProgressBar.swift
//  Gita
//

import SwiftUI

/// A filled track, themed.
///
/// Hand-rolled rather than SwiftUI's `ProgressView`, which takes its fill from
/// the system tint and so draws blue in Light and stays blue in Sepia. Shared
/// by the reader's position rail and the chapter rows in Progress, which were
/// the same ten lines twice with different heights.
struct ProgressBar: View {
    /// 0...1. Values outside are clamped rather than drawn past the track.
    let fraction: Double
    var height: CGFloat = 3
    /// A floor for the fill, so "barely started" still reads as a mark rather
    /// than as nothing. Zero leaves an empty track empty.
    var minimumWidth: CGFloat = 0

    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.divider)
                Capsule()
                    .fill(theme.accent)
                    .frame(width: max(minimumWidth, proxy.size.width * fraction.clamped()))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

private extension Double {
    func clamped() -> Double { min(1, max(0, self)) }
}
