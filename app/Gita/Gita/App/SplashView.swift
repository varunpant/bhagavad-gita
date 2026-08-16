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

    /// Yellow at the top through to vermillion at the foot — the icon's ground,
    /// run vertically over the whole screen.
    private let ground = LinearGradient(
        colors: [
            Color(red: 0xF2 / 255, green: 0xC2 / 255, blue: 0x30 / 255),
            Color(red: 0xF0 / 255, green: 0x86 / 255, blue: 0x1E / 255),
            Color(red: 0xE0 / 255, green: 0x3C / 255, blue: 0x24 / 255),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            ground.ignoresSafeArea()

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
                return
            }
            withAnimation(.smooth(duration: 0.55)) { markShown = true }
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.smooth(duration: 0.5)) { wordmarkShown = true }
        }
        .accessibilityElement()
        .accessibilityLabel("श्रीमद् भगवद्गीता")
    }
}

#Preview { SplashView() }
