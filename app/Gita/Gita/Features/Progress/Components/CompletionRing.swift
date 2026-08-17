//
//  CompletionRing.swift
//  Gita
//

import SwiftUI

/// How much of the Gita has been read, as a ring.
///
/// Drawn in `theme.accent` — which resolves to plain black outside Sepia — and
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
            Circle()
                .stroke(theme.divider, lineWidth: 10)

            Circle()
                .trim(from: 0, to: shown)
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                // From twelve o'clock rather than three, which is where a
                // progress ring is read from.
                .rotationEffect(.degrees(-90))

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
