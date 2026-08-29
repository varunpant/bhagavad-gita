//
//  WelcomeVignette.swift
//  Gita
//

import SwiftUI

/// A screenshot of the screen a welcome page is talking about.
///
/// Real captures of the running app, shot by `WelcomeArtUITests` in both
/// scripts and packed into the asset catalogue by `tools/make_welcome_art.py`.
/// They have to be reshot when the screens change — that is the price of
/// showing the reader the app rather than a drawing of it, and the same bargain
/// this repository already makes with `gita.sqlite` and the social cards.
///
/// Framed as a store listing frames a screen: a card with a hairline, and the
/// picture dissolving at the top and the bottom so it reads as a window onto
/// something larger rather than a photograph that stops.
struct WelcomeVignette: View {
    /// Asset name without the script suffix — `scripture`, `search`, and so on.
    let art: String
    let isDevanagari: Bool
    var body: some View {
        Image("welcome-\(art)-\(isDevanagari ? "sa" : "en")")
            .resizable()
            .aspectRatio(contentMode: .fill)
            // Sized against the screen rather than in fixed points: a phone, an
            // iPad and a Mac window are three very different amounts of room,
            // and one 320pt card left two of them mostly empty. Capped, because
            // past about 700pt a screenshot of a phone stops looking like one.
            .containerRelativeFrame([.horizontal, .vertical], alignment: .top) { length, axis in
                axis == .horizontal ? min(length * 0.86, 700) : length * 0.50
            }
            .clipped()
            // Dissolves on all four sides. Top and bottom because the screen
            // carries on past the card; left and right just enough to take the
            // hard edge off, so the shot sits *in* the page rather than on it.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.10),
                        .init(color: .black, location: 0.86),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.04),
                        .init(color: .black, location: 0.96),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            // No border and barely a shadow. A hairline round a white
            // screenshot on a white page draws a box where the eye wants a
            // window; the faintest lift is enough to say the shot is nearer
            // than the page.
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.07), radius: 24, y: 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .accessibilityHidden(true)
    }
}
