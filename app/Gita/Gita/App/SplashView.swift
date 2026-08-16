//
//  SplashView.swift
//  Gita
//

import SwiftUI

/// A title page: the mark and wordmark on the brand's marigold ground.
///
/// Full-bleed and coloured regardless of theme. This is the one screen that is
/// the brand rather than the reading surface — the app it hands over to is
/// deliberately plain, so the colour belongs here and nowhere else.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Two stages: the mark arrives, the wordmark follows a beat later. A
    /// single simultaneous fade reads as a static image that happens to appear.
    @State private var markShown = false
    @State private var wordmarkShown = false
    /// The ground resolves from soft to sharp over two seconds.
    @State private var crisp = false

    var body: some View {
        ZStack {
            Brand.gradient
                // Scaled up while blurred: a blur samples past its own edges, so
                // an unscaled gradient would show pale fringes down the sides.
                .scaleEffect(crisp ? 1 : 1.3)
                .blur(radius: crisp ? 0 : 60)
                // Blurring a smooth gradient barely reads — a blurred gradient
                // is still a gradient. The intensity ramp is what carries it:
                // washed out and dim, resolving to full colour.
                .saturation(crisp ? 1 : 0.30)
                .brightness(crisp ? 0 : 0.10)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(verbatim: "ग")
                    .font(.custom("KohinoorDevanagari-Light", size: 96))
                    .foregroundStyle(.white)
                    .opacity(markShown ? 1 : 0)
                    .scaleEffect(markShown ? 1 : 0.88)

                VStack(spacing: -2) {
                    Text(verbatim: "श्रीमद्")
                        .font(.custom("KohinoorDevanagari-Light", size: 26))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(verbatim: "भगवद्गीता")
                        .font(.custom("KohinoorDevanagari-Medium", size: 34))
                        .foregroundStyle(.white)
                }
                .opacity(wordmarkShown ? 1 : 0)
                .offset(y: wordmarkShown ? 0 : 10)
            }
        }
        .task {
            guard !reduceMotion else {
                markShown = true
                wordmarkShown = true
                crisp = true
                return
            }
            // The ground sharpens across the whole splash; the mark and wordmark
            // arrive early so there is something to look at while it resolves.
            withAnimation(.easeOut(duration: 2.0)) { crisp = true }
            withAnimation(.smooth(duration: 0.55)) { markShown = true }
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.smooth(duration: 0.5)) { wordmarkShown = true }
        }
        .accessibilityElement()
        .accessibilityLabel("श्रीमद् भगवद्गीता")
    }
}

#Preview { SplashView() }
