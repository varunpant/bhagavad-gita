//
//  CompletionRing.swift
//  Gita
//

import SwiftUI

/// How much of the Gita has been read, as a ring.
///
/// Drawn in the brand ramp — the one thing on the panel that carries it — and
/// deliberately **not** in `Brand.gradient`. The rail and the splash are the
/// app's two brand exceptions; a marigold ring would put colour back onto a
/// light-theme reading screen, which is the rule this app keeps.
struct CompletionRing: View {
    /// 0...1.
    let completion: Double
    let versesRead: Int
    let totalVerses: Int
    let isDevanagari: Bool

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Animated from zero on appear, so the ring draws itself rather than
    /// snapping into place — the one flourish this screen gets.
    @State private var shown: Double = 0

    private var percent: Int { Int((completion * 100).rounded()) }

    var body: some View {
        ZStack {
            // The widget's ring, drawn here too — the same number in two
            // places should not be two designs. It was the same saffron sweep
            // already, but over `theme.divider`: a cold grey track beside a
            // saffron arc, which is what the comment on `Theme.track` exists
            // to argue against. Only this screen animates it, so the sweep is
            // passed in rather than owned by the ring.
            BrandRing(completion: shown, theme: theme)

            VStack(spacing: 2) {
                Text("\(percent.digits(devanagari: isDevanagari))%")
                    .font(.system(size: 34, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)

                Text(count)
                    .font(isDevanagari ? .labelDevanagari : .label)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(width: 168, height: 168)
        .padding(.vertical, 8)
        .task(id: completion) {
            guard !reduceMotion else { shown = completion; return }
            withAnimation(.smooth(duration: 0.8)) { shown = completion }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(percent) percent read, \(versesRead) of \(totalVerses) verses")
    }

    private var count: String {
        Int.ratio(versesRead, of: totalVerses, devanagari: isDevanagari, separator: " / ")
    }
}
