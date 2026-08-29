//
//  PanelColumns.swift
//  Gita
//

import SwiftUI

/// How many cards a panel puts across.
///
/// Two on a phone, more on an iPad or a Mac. One rule in one place because the
/// contents and the goals both ask it, and a panel where the chapters are two
/// across and the goals are four would not read as one screen.
///
/// Size class rather than a measured width: the panels sit in a fixed-width
/// column beside the rail, so their width is a property of the device, and a
/// `GeometryReader` here would defeat the laziness of the list inside it.
///
/// Why not `GridItem(.adaptive(minimum:))`, which needs no count at all: the
/// contents expand a chapter in place, and inserting the verses *after the row
/// that holds the tapped card* means knowing which cards share a row. Adaptive
/// grids do not say.
nonisolated enum PanelColumns {
    /// Chapters and goals: wide cards, because an English chapter name is a
    /// phrase where its Devanagari form is one compound. Three narrow columns
    /// hyphenated "The Despondency of Arjuna" into rubble at large text sizes.
    static let cards = Layout(compact: 2, regular: 3)

    /// Goals carry a symbol and a name, so they take one more across than a
    /// chapter card, which also has to hold a count and a progress marker.
    static let badges = Layout(compact: 2, regular: 4)

    struct Layout: Sendable {
        let compact: Int
        let regular: Int

        #if os(iOS)
        /// Size class, not idiom: an iPad running two apps side by side is
        /// compact and wants a phone's two columns, and asking the device would
        /// give it three in half the width.
        func count(for sizeClass: UserInterfaceSizeClass?) -> Int {
            sizeClass == .compact ? compact : regular
        }
        #else
        /// A Mac window is never compact.
        var count: Int { regular }
        #endif
    }
}

/// Splits a list into rows of `size`, keeping order. The last row is short
/// rather than padded — the views decide what to do with the gap, and a padded
/// model would put empty chapters in the data.
extension Array {
    func inRows(of size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension View {
    /// `fullScreenCover` on iOS, a plain `sheet` on macOS, where it does not
    /// exist. One helper rather than an `#if` at the call site.
    @ViewBuilder
    func fullScreenCoverIfAvailable<Content: View>(
        isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}
