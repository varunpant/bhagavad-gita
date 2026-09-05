//
//  WelcomeVersePair.swift
//  Gita
//

import SwiftUI

// The reading surface as a pair of cards, for the two pages that show the verse
// itself rather than a screenshot of it.

// MARK: - The verse, in both scripts

/// The reading surface, shown as a pair of cards rather than as a screenshot.
///
/// Two full phones side by side on a 440pt page would set the shloka at about
/// ten points, which is the illegibility this whole screen exists to undo. Two
/// cards at very nearly the page width keep the type at reading size, and a
/// crop of the one thing a page is about is more honest than a squeezed whole
/// screen. The pair is also the argument: one switch turns the page from the
/// top card to the bottom one, and the reader sees both ends before choosing.
struct WelcomeVersePair: View {
    enum Kind { case meaning, wordByWord }
    let kind: Kind
    let metrics: WelcomeMetrics
    let fitting: CGSize

    /// Asked of the slot, not of the page.
    ///
    /// The pair has a fixed words band above it and the controls below, so on
    /// a phone it has to earn its height: a step off the shloka, the gloss and
    /// the padding is what keeps both cards whole. Deciding this from the
    /// page's *height* instead reads a 6.9" phone as roomy and sets the cards
    /// at their full size in a slot that cannot hold them, which cuts the
    /// second card's meaning off mid-line. The slot knows; the page does not.
    private var compact: Bool { metrics.isTightSlot(fitting) }

    var body: some View {
        VStack(spacing: compact ? 14 : 18) {
            card(devanagari: true)
            card(devanagari: false)
        }
        // Fixed to the column it was given. A card has a minimum width its
        // padding and type insist on; below that it overflows and spills over
        // whatever is beside it, which is what `ViewThatFits` is there to
        // prevent by scrolling instead.
        .frame(width: max(0, min(fitting.width, metrics.artWidth)), alignment: .top)
    }

    @ViewBuilder
    private func card(devanagari: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(devanagari ? WelcomeSample.shlokaSa : WelcomeSample.shlokaEn)
                    .font(shlokaFont(devanagari))
                    .lineSpacing(devanagari ? 12 : 8)
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text(devanagari ? "देवनागरी" : "English")
                    .font(devanagari ? .labelDevanagari : .label)
                    .tracking(devanagari ? 0 : 1.4)
                    .textCase(devanagari ? nil : .uppercase)
                    .foregroundStyle(WelcomeInk.accent)
                    .layoutPriority(1)
            }

            Rectangle()
                .fill(.black.opacity(0.09))
                .frame(height: 1)

            switch kind {
            case .meaning:
                block(devanagari ? "अनुवाद" : "Translation",
                      devanagari ? WelcomeSample.translationSa : WelcomeSample.translationEn,
                      devanagari: devanagari)
                block(devanagari ? "भावार्थ" : "Meaning",
                      devanagari ? WelcomeSample.meaningSa : WelcomeSample.meaningEn,
                      devanagari: devanagari)
            case .wordByWord:
                label(devanagari ? "शब्दार्थ" : "Word by word", devanagari: devanagari)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(devanagari ? WelcomeSample.wordsSa : WelcomeSample.wordsEn, id: \.word) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Text(row.word)
                                .font(devanagari ? .wordDevanagari : .wordLatin)
                                .frame(width: 104, alignment: .leading)
                            Text(row.gloss)
                                .font(devanagari ? .glossDevanagari : .glossLatin)
                                .foregroundStyle(.black.opacity(0.62))
                        }
                    }
                }
                .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, compact ? 18 : 20)
        .padding(.vertical, compact ? 15 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(WelcomeInk.cardEdge, lineWidth: 1)
                }
        }
        .shadow(color: WelcomeInk.ink.opacity(0.10), radius: 20, y: 8)
        .accessibilityElement(children: .combine)
    }

    /// The word page sets the shloka smaller: five gloss rows and a display
    /// line do not both fit at reading size, and on that page the words are
    /// the subject.
    private func shlokaFont(_ devanagari: Bool) -> Font {
        let size: CGFloat = kind == .meaning ? (compact ? 19 : 21) : (compact ? 16 : 17)
        return .card(devanagari: devanagari, size: size)
    }

    @ViewBuilder
    private func label(_ text: String, devanagari: Bool) -> some View {
        Text(text)
            .font(devanagari ? .labelDevanagari : .label)
            .tracking(devanagari ? 0 : 1.2)
            .textCase(devanagari ? nil : .uppercase)
            .foregroundStyle(.black.opacity(0.5))
    }

    @ViewBuilder
    private func block(_ title: String, _ text: String, devanagari: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 6) {
            label(title, devanagari: devanagari)
            Text(text)
                .font(compact ? .card(devanagari: devanagari, size: 14.5)
                              : (devanagari ? .glossDevanagari : .glossLatin))
                .lineSpacing(4)
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The one verse the guide teaches with.
///
/// Held here rather than read from `Library`, because the welcome can be on
/// screen before the corpus has finished loading and a guide that shows an
/// empty card while it waits is worse than one that carries its own example.
/// `WelcomeSampleTests` checks these strings against `gita.sqlite`, so they
/// cannot drift from the text the reader will actually meet at 2.47.
/// `nonisolated`, like `FamousVerses`: this is a constant about the text, and
/// the suite that pins it to the corpus has no reason to be on the main actor.
