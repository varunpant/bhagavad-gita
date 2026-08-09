//
//  SplashView.swift
//  Gita
//

import SwiftUI

/// A title page: the app's letterform on the reading ground, held briefly and
/// handed over with a tap of feedback.
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

            Text(verbatim: "g")
                .font(.custom("Georgia-Bold", size: 132))
                .foregroundStyle(theme.accent)
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
