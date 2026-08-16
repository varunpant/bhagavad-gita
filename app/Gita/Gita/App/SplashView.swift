//
//  SplashView.swift
//  Gita
//

import SwiftUI

/// A title page: the brand's ग on the reading ground, held briefly and handed
/// over with a tap of feedback.
///
/// It follows the theme like everything else — plain in Light and Dark, warm in
/// Sepia — so the first thing seen matches the app that follows it.
struct SplashView: View {
    @Environment(\.theme) private var theme

    /// Animated in rather than shown flat, so the handover has somewhere to go.
    @State private var settled = false

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            // The brand mark itself, so the vermillion is deliberate rather
            // than a stray colour in an otherwise monochrome interface.
            Text(verbatim: "ग")
                .font(.custom("KohinoorDevanagari-Medium", size: 148))
                .foregroundStyle(Color(red: 0xE0 / 255, green: 0x3C / 255, blue: 0x24 / 255))
                .scaleEffect(settled ? 1 : 0.86)
                .opacity(settled ? 1 : 0)
        }
        .task {
            withAnimation(.smooth(duration: 0.5)) { settled = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Gita")
    }
}

#Preview { SplashView().environment(\.theme, .sepia) }
