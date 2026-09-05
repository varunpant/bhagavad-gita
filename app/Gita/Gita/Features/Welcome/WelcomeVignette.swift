//
//  WelcomeVignette.swift
//  Gita
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - A screen, in a device

/// A screenshot of the screen a welcome page is talking about.
///
/// Real captures of the running app, shot by `WelcomeArtUITests` in both
/// scripts and packed into the asset catalogue by `tools/make_welcome_art.py`.
/// They have to be reshot when the screens change — that is the price of
/// showing the reader the app rather than a drawing of it, and the same bargain
/// this repository already makes with `gita.sqlite` and the social cards.
///
/// **The whole screen, at its own aspect, in a frame.** The first version put a
/// 1320 × 2868 capture into a box 88% of the width by *half the height* with
/// `contentMode: .fill`, which on a phone is very nearly square: a tall screen
/// was cropped to a random horizontal band, and two four-stop dissolves then
/// took the edges off it. It read as a grey smudge rather than as a picture of
/// the app. Nothing is cropped here and nothing dissolves; the dark bezel is
/// what gives the shot an edge, and running off the bottom of the page is what
/// says the screen carries on past it.
struct WelcomeVignette: View {
    /// Asset name without the script suffix — `contents`, `search`, and so on.
    let art: String
    let isDevanagari: Bool
    let metrics: WelcomeMetrics
    /// The space the layout actually has left for the art, measured rather
    /// than guessed. See `WelcomeArtBox`.
    let fitting: CGSize

    @Environment(WelcomeArtStore.self) private var store

    /// The asset this page draws — named by `WelcomeArt`, which is where the
    /// rule lives for the store, the tests and the capture tool alike.
    var assetName: String {
        WelcomeArt.screen(art).assetName(isDevanagari: isDevanagari) ?? ""
    }

    /// What the capture would be if nothing had been done to it, and the only
    /// thing left to fall back on if the asset cannot be measured.
    private static let captureAspect: CGFloat = 1320.0 / 2868.0

    /// The shot's own aspect, **read from the asset** rather than assumed.
    ///
    /// This was the constant above, which is the shape a capture has as it
    /// comes off the simulator — and not the shape of anything in the asset
    /// catalogue. `tools/make_welcome_art.py` trims the status bar off every
    /// shot and crops the rail off two of them, so what is actually bundled is
    /// 1260 × 2614 or 1104 × 2739. Neither is 1320 × 2868.
    ///
    /// That difference is not a letterbox. The glass below is given an
    /// explicit size with no `contentMode`, so a mismatch is a *stretch*: the
    /// appearance and progress panels were being drawn fourteen per cent wider
    /// than they are, which is why their rows read squat and their toggles
    /// read fat. Measuring the asset means any crop the tool applies — today's
    /// or tomorrow's — is drawn at its own proportions and needs no constant
    /// here kept in step with it.
    private var shotAspect: CGFloat {
        // From the image the store already decoded. This used to load the asset
        // a second time, on the main actor, during layout — the very thing
        // `WelcomeArtStore` exists to keep off this path — and memoise it in a
        // static cache of its own with its own platform fork.
        guard let size = store.images[assetName]?.size, size.height > 0 else {
            return Self.captureAspect
        }
        return size.width / size.height
    }

    /// The decoded shot, or nothing if the warm-up has not reached it yet.
    ///
    /// Nothing is drawn rather than a spinner or a grey block: the bezel is
    /// already on screen, and an empty piece of glass for a fraction of a
    /// second reads as a screen about to light up.
    @ViewBuilder
    private var glass: some View {
        if let shot = store.images[assetName] {
            #if canImport(UIKit)
            Image(uiImage: shot).resizable().transition(.opacity)
            #else
            Image(nsImage: shot).resizable().transition(.opacity)
            #endif
        } else {
            Color.black.opacity(0.04)
        }
    }

    /// Bezel and corner, as shares of the device’s own width.
    ///
    /// The panel draws a 320pt device with a 7pt bezel and a 40pt corner. Held
    /// as constants those are right at exactly one size and wrong at every
    /// other: shrink the device to 190pt and the same seven points is half
    /// again as thick, while a 40pt radius on a 190pt box rounds the corners
    /// until the dark frame and the rounded shot inside it read as two heavy
    /// borders around a small picture. As shares they keep their proportion at
    /// any width.
    /// The panel’s own number: a 320pt device on a 440pt page, which leaves a
    /// margin of ground down either side rather than running edge to edge.
    /// Held as a share of the page, so a wider column gets a proportionally
    /// wider device rather than the same 320 marooned in the middle of it.
    private static let widthShare: CGFloat = 320 / WelcomeMetrics.referenceWidth

    private static let bezelShare: CGFloat = 7.0 / 320.0
    private static let radiusShare: CGFloat = 40.0 / 320.0

    /// The aspect of the whole device — shot plus bezel on all four sides.
    ///
    /// Not the same as the shot’s, and the difference is what crops the top
    /// line off a screenshot if the outer box is sized at `shotAspect` and the
    /// image inside told to fill it. Derived rather than typed: the glass is
    /// `1 - 2·bezelShare` of the width, so the whole thing is that much of the
    /// shot’s height plus the two bezels.
    private var frameAspect: CGFloat {
        1 / ((1 - 2 * Self.bezelShare) / shotAspect + 2 * Self.bezelShare)
    }

    /// How wide the device is drawn.
    ///
    /// Width first, always — the shot is a portrait phone, and its width is
    /// what decides whether the type inside it can be read at all. There is no
    /// height term here on purpose: the device is allowed to run off the foot
    /// of the page, so the slot's height caps what is *drawn*, never what is
    /// drawn *at*. Sizing the width to fit between the body text and the button
    /// is what made it small — on a 6.9" phone that came out a 190pt phone
    /// drawn inside a 440pt one, all bezel and no screen.
    private var width: CGFloat {
        max(0, min(fitting.width, metrics.artWidth, metrics.pageWidth * Self.widthShare))
    }

    var body: some View {
        let full = width / frameAspect
        device(width: width, height: full)
            // Reports the slot it was given, and draws past it, where the
            // controls' scrim fades it out instead of a hard edge cutting it.
            .frame(width: width,
                   height: max(0, min(full, fitting.height)),
                   alignment: .top)
            .accessibilityHidden(true)
    }

    /// The shot, its bezel and its shadow, at an explicit size.
    ///
    /// Explicit rather than `.aspectRatio(_:contentMode:)` under a flexible
    /// frame, which does not hold — the frame stretches the composed device,
    /// bezel and all, and the shot inside comes out the wrong shape.
    private func device(width: CGFloat, height: CGFloat) -> some View {
        let bezel = max(3, width * Self.bezelShare)
        let outer = width * Self.radiusShare
        // No `contentMode` — the glass is given the exact size the shot’s own
        // aspect asks for, so there is nothing left to fill or fit.
        return glass
            .frame(width: max(0, width - bezel * 2), height: max(0, height - bezel * 2))
            .clipShape(RoundedRectangle(cornerRadius: max(2, outer - bezel), style: .continuous))
            .padding(bezel)
            .background {
                RoundedRectangle(cornerRadius: outer, style: .continuous)
                    .fill(Color(.sRGB, red: 0x1A / 255, green: 0x14 / 255, blue: 0x12 / 255, opacity: 1))
            }
            .shadow(color: WelcomeInk.ink.opacity(0.20), radius: 30, y: 14)
            // The picture crosses into the glass rather than appearing in it.
            // A quarter of a second: long enough to read as a fade, short
            // enough that nobody waits for it.
            .animation(.easeOut(duration: 0.25), value: store.images[assetName] != nil)
    }
}
