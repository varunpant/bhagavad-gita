//
//  WelcomeArtStore.swift
//  Gita
//

import SwiftUI
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

/// The guide's screenshots, decoded once, at the size they are drawn.
///
/// `Image("name")` looks easy and is not: the catalogue decodes the file the
/// first time the view draws, on the main thread, and these are 1260px PNGs.
/// In a `LazyHStack` that decode lands exactly when the page scrolls in — so
/// the swipe that brings a page into view is the swipe that stutters, and the
/// picture appears a frame later with a snap.
///
/// So the shots are decoded off the main actor before the guide is swiped, and
/// the views draw an image that is already in memory. What is left is a fade
/// rather than a pop.
///
/// **Two things this must not do, both learned the expensive way.** Decoding
/// every asset at full size costs 122 MB of ARGB bitmaps — measured, not
/// estimated: ten shots at 1260x2614 and 1104x2739. And half of them are in a
/// script the reader has not chosen and will never see on this run. So it warms
/// one script, and it warms it at the size the page actually draws, which on a
/// phone is about a third of the file's own width. First launch is the worst
/// possible moment to ask a device for a hundred megabytes.
@Observable
final class WelcomeArtStore {

    private(set) var images: [String: PlatformImage] = [:]

    /// Guards re-entry, and records the script warmed — switching language on
    /// the title page has to fetch the other five.
    private var warmed: Set<String> = []

    /// Every screenshot the guide can ask for, in one script.
    ///
    /// Built from `WelcomeArt.assetName`, which is the one place the naming
    /// rule lives — the vignette draws with it and `WelcomeArtAssetTests` pins
    /// it, so a tenth page cannot arrive unwarmed or untested.
    static func names(isDevanagari: Bool) -> [String] {
        WelcomePage.all.compactMap { $0.art.assetName(isDevanagari: isDevanagari) }
    }

    /// Both scripts, for the test that checks the catalogue has everything.
    static var allNames: [String] { names(isDevanagari: true) + names(isDevanagari: false) }

    /// Decode this script's shots, off the main actor, then publish in one go.
    ///
    /// One assignment rather than five: each is an observable change that
    /// redraws every page holding an image, and doing that per file during a
    /// swipe is the stutter this exists to remove.
    ///
    /// - Parameter pixelWidth: how wide the shot is actually drawn, in pixels.
    ///   Anything more is a bitmap nobody looks at.
    func warm(isDevanagari: Bool, pixelWidth: CGFloat) async {
        let wanted = Self.names(isDevanagari: isDevanagari).filter { !warmed.contains($0) }
        guard !wanted.isEmpty else { return }

        // Concurrently: these are independent decodes and the device has more
        // than one core. Serially, the warm-up cost the sum of all five.
        var decoded: [String: PlatformImage] = [:]
        await withTaskGroup(of: (String, PlatformImage?).self) { group in
            for name in wanted {
                group.addTask { (name, await Self.decode(name, pixelWidth: pixelWidth)) }
            }
            for await (name, image) in group {
                if let image { decoded[name] = image }
            }
        }

        warmed.formUnion(wanted)
        images.merge(decoded) { _, new in new }
    }

    /// Off the main actor: `@concurrent` because a `nonisolated async` function
    /// stays on its caller's actor under approachable concurrency, and the
    /// whole point here is to be somewhere else while this happens.
    @concurrent
    private nonisolated static func decode(
        _ name: String, pixelWidth: CGFloat
    ) async -> PlatformImage? {
        #if canImport(UIKit)
        guard let full = UIImage(named: name) else { return nil }
        guard pixelWidth > 0, full.size.width > pixelWidth else {
            return full.preparingForDisplay() ?? full
        }

        let size = CGSize(width: pixelWidth,
                          height: (pixelWidth * full.size.height / full.size.width).rounded())
        let format = UIGraphicsImageRendererFormat()
        // One pixel per point: the size above is already in pixels, and letting
        // the renderer apply the screen's scale on top is how a "downscale"
        // ends up three times larger than the original.
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            full.draw(in: CGRect(origin: .zero, size: size))
        }
        #else
        guard let full = NSImage(named: name) else { return nil }
        guard pixelWidth > 0, full.size.width > pixelWidth else { return full }

        let size = NSSize(width: pixelWidth,
                          height: (pixelWidth * full.size.height / full.size.width).rounded())
        let scaled = NSImage(size: size)
        scaled.lockFocus()
        full.draw(in: NSRect(origin: .zero, size: size))
        scaled.unlockFocus()
        return scaled
        #endif
    }
}
