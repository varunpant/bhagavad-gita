//
//  Haptics.swift
//  Gita
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Physical feedback, in one place so the whole app is consistent about it.
///
/// Two intensities, deliberately: changing a setting is a small confirmation,
/// while turning to another verse is the app's central gesture and should feel
/// like a page moving. Anything more elaborate becomes noise in a reader.
///
/// Cross-platform by design — most Macs have no taptic engine, so these become
/// no-ops there rather than littering the call sites with `#if`.
enum Haptics {
    /// A setting changed: a toggle flipped, a picker moved.
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }

    /// The reader moved to another verse — by swipe, by the chevrons, or by a
    /// jump from the contents. Firmer than `selection`, because it stands in for
    /// the feel of a page turning.
    static func pageTurn() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #endif
    }
}
