//
//  Confetti.swift
//  Gita
//

import SwiftUI

/// A short fall of paper, for the moment a goal is earned.
///
/// Drawn rather than pulled in: a confetti library is a dependency, an asset
/// bundle and a particle system for two seconds of paper. This is fifty
/// rectangles falling under a fixed animation, in the brand's own colours.
///
/// Three things keep it from becoming a nuisance in a reader:
///
/// - **It is never in the way.** Nothing here takes a tap
///   (`allowsHitTesting(false)`), and it removes itself when the toast that
///   raised it goes.
/// - **It obeys Reduce Motion.** Falling paper is exactly what that setting is
///   about; with it on, the pieces do not appear at all — the toast and the
///   haptic still mark the moment.
/// - **It is the same every time for the same goal.** The layout is seeded from
///   the badge, so a screenshot of "Steady in Wisdom" looks the same on every
///   run, and the design checks do not shift under their own randomness.
struct Confetti: View {
    /// Anything stable about the occasion — a badge id will do. The same seed
    /// gives the same fall.
    let seed: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fallen = false

    private static let count = 50

    var body: some View {
        GeometryReader { geometry in
            if !reduceMotion {
                ZStack(alignment: .topLeading) {
                    ForEach(pieces(in: geometry.size), id: \.id) { piece in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(piece.colour)
                            .frame(width: piece.width, height: piece.height)
                            .rotationEffect(.degrees(fallen ? piece.spin : 0))
                            .offset(
                                x: piece.x + (fallen ? piece.drift : 0),
                                y: fallen ? geometry.size.height + 40 : -60
                            )
                            .opacity(fallen ? 0 : 1)
                            .animation(
                                .easeIn(duration: piece.duration).delay(piece.delay),
                                value: fallen
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // A tick after the first render rather than in `onAppear`.
                //
                // A state change made during `onAppear` can land in the same
                // transaction as the view's insertion, and SwiftUI then applies
                // it with no animation — every piece would go from above the
                // screen to below it in one frame, and the confetti would be
                // invisible while looking perfectly correct in the code. One
                // frame's wait puts it in a transaction of its own.
                .task {
                    try? await Task.sleep(for: .milliseconds(16))
                    fallen = true
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - The paper

    private struct Piece {
        let id: Int
        let x: CGFloat
        let drift: CGFloat
        let spin: Double
        let width: CGFloat
        let height: CGFloat
        let delay: Double
        let duration: Double
        let colour: Color
    }

    /// Laid out from the seed rather than from `Double.random`, so the same goal
    /// falls the same way twice — and so a preview or a screenshot is stable.
    ///
    /// A tiny hash per piece: enough scatter that no two pieces line up, and
    /// nothing that needs a generator to be held anywhere.
    private func pieces(in size: CGSize) -> [Piece] {
        (0 ..< Self.count).map { index in
            let a = noise(index, 1)
            let b = noise(index, 2)
            let c = noise(index, 3)
            let d = noise(index, 4)

            return Piece(
                id: index,
                x: a * max(size.width - 10, 1),
                drift: (b - 0.5) * 90,
                spin: 180 + c * 540,
                width: 5 + d * 5,
                height: 9 + b * 7,
                // Spread the start over half a second, so it falls as a shower
                // rather than as a curtain.
                delay: a * 0.5,
                duration: 1.5 + c * 1.1,
                colour: Brand.ramp[index % Brand.ramp.count]
            )
        }
    }

    private func noise(_ index: Int, _ salt: Int) -> CGFloat {
        var value = UInt64(bitPattern: Int64(seed &* 2_654_435_761))
        value ^= UInt64(index &* 40_503 &+ salt &* 2_246_822_519)
        value = value &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return CGFloat((value >> 33) % 1_000) / 1_000
    }
}

#Preview {
    ZStack {
        Color.white
        Confetti(seed: 42)
    }
}
