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
/// Four intensities, deliberately: changing a setting is a small confirmation,
/// turning to another verse is the app's central gesture and should feel like a
/// page moving, a swipe that meets the end of the book is that same page
/// refusing to move, and earning a goal happens rarely enough to be allowed the
/// system's own success pattern. Anything more elaborate becomes noise in a
/// reader.
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

    /// The rail slid in or out, by the menu button or by a drag.
    ///
    /// Firmer than `selection`, which is a tick for a value changing and is too
    /// slight for something the size of the screen moving; softer than
    /// `pageTurn`, which stands for the book itself.
    static func panel() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.7)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #endif
    }

    /// The reader tried to turn past the end of the book, or back before its
    /// beginning.
    ///
    /// Softer than `pageTurn`, and deliberately dull: the page turn is a page
    /// moving, and this is the feel of one that did not. A warning pattern was
    /// wrong here — nothing has gone wrong, there is simply nothing there.
    static func edge() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.55)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }

    /// A goal was earned. The system's success pattern rather than an impact:
    /// it is two taps with a rise between them, which is what "well done" feels
    /// like on iOS, and every other app the reader owns uses the same one.
    ///
    /// Rare by construction — thirty-five goals across a whole book — so it can
    /// afford to be the firmest thing the app does.
    static func celebrate() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
}
