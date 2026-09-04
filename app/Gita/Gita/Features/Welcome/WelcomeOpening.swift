//
//  WelcomeOpening.swift
//  Gita
//

import SwiftUI

/// The title page: the name, the greeting, and the one question.
///
/// This was two pages — an app mark with a sentence, then a language choice —
/// doing one job between them across two swipes, with neither filling its own
/// screen. Merged, and organised as three zones with a hairline between the
/// first and the second:
///
/// - **Name.** The wordmark, and the one sentence that says what the app is.
/// - **Greeting.** The Rigveda line, its gloss, its reference.
/// - **The ask.** A small label and the two pills.
///
/// **No app mark.** The splash has just held it for two seconds and handed
/// over; showing it again on the next screen says nothing new, and it pushed
/// the language choice — the only thing this page actually needs from the
/// reader — down towards the fold.
///
/// **The air between the zones is elastic.** It used to be four hard-coded
/// paddings adding up to a page 6.9" tall, and on a 4.7" phone that overran the
/// bottom by about a hundred and fifty points: the pills came to rest under the
/// dots with the button drawn across them. The gaps are `Spacer`s now, with a
/// floor that keeps the zones apart on the shortest page and a ceiling that
/// stops them drifting apart on an iPad — and the type is sized from
/// `WelcomeMetrics` like every other page rather than from two literals.
///
/// Both scripts appear here and only here. The reader has not chosen one yet,
/// and this is the page that asks; everything after it is in their answer.
struct WelcomeOpening: View {
    let isDevanagari: Bool
    let metrics: WelcomeMetrics
    var onChoose: (ReadingLanguage) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: "स्वागत · Welcome")
                .font(.custom(Fonts.devanagari, size: metrics.kickerSize + 2).weight(.medium))
                .tracking(1.4)
                .foregroundStyle(WelcomeInk.accent)
                .padding(.bottom, metrics.roomy ? 34 : 24)

            // Sized from the page like every heading in the guide, and allowed
            // to shrink rather than wrap: a two-line wordmark is not a wordmark.
            Text(verbatim: "श्रीमद्भगवद्गीता")
                .font(.custom(Fonts.devanagari, size: metrics.titleSize + 7).weight(.medium))
                .foregroundStyle(WelcomeInk.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.bottom, metrics.roomy ? 18 : 12)

            Text(isDevanagari
                 ? "सात सौ श्लोक — अनुवाद और भावार्थ सहित, बिना इंटरनेट के।"
                 : "All 700 verses, translated and explained. Always offline.")
                .font(isDevanagari
                      ? .custom(Fonts.devanagari, size: metrics.bodySize + 1).weight(.light)
                      : .custom(Fonts.latin, size: metrics.bodySize))
                .foregroundStyle(WelcomeInk.mute)
                .lineSpacing(5)
                .frame(maxWidth: 340)
                .fixedSize(horizontal: false, vertical: true)

            gap(min: 22, max: 60)

            Rectangle()
                .fill(WelcomeInk.hairline)
                .frame(height: 1)

            gap(min: 22, max: 60)

            blessing

            gap(min: 26, max: 74)

            Text(isDevanagari ? "पढ़ें" : "Read in")
                .font(isDevanagari ? .labelDevanagari : .label)
                .tracking(isDevanagari ? 0 : 2.4)
                .textCase(isDevanagari ? nil : .uppercase)
                .foregroundStyle(WelcomeInk.mute)
                .padding(.bottom, 16)

            languageChoice
        }
        .multilineTextAlignment(.center)
        // Fills the page so the gaps have slack to share out, and takes it back
        // from the bottom first — the zones sit at the top of a tall page
        // rather than floating in the middle of it.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, metrics.roomy ? 32 : 8)
    }

    /// Air with a floor and a ceiling.
    ///
    /// The floor is what the zones need to read as separate zones on the
    /// shortest phone; the ceiling stops an iPad's spare six hundred points
    /// being shared out until the page comes apart.
    private func gap(min floor: CGFloat, max ceiling: CGFloat) -> some View {
        Spacer(minLength: floor).frame(maxHeight: ceiling)
    }

    /// The Rigveda's welcome, which is older than the Gita and is what this
    /// tradition says to someone arriving.
    private var blessing: some View {
        VStack(spacing: 10) {
            Text(verbatim: "आ नो भद्राः क्रतवो यन्तु विश्वतः")
                .font(.custom(Fonts.devanagari, size: metrics.roomy ? 30 : 23).weight(.light))
                .foregroundStyle(WelcomeInk.ink)
                .lineSpacing(10)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "Let noble thoughts come to us from every side")
                .font(.custom(Fonts.latin, size: metrics.roomy ? 18 : 15))
                .foregroundStyle(WelcomeInk.mute)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "ऋग्वेद १.८९.१  ·  Rigveda 1.89.1")
                .font(.custom(Fonts.devanagari, size: 11).weight(.medium))
                .foregroundStyle(WelcomeInk.mute.opacity(0.85))
                .padding(.top, 2)
        }
        .accessibilityElement(children: .combine)
    }

    private var languageChoice: some View {
        HStack(spacing: 12) {
            ForEach(ReadingLanguage.allCases) { language in
                let selected = (language.isDevanagari == isDevanagari)
                Button {
                    Haptics.selection()
                    onChoose(language)
                } label: {
                    Text(language.isDevanagari ? "देवनागरी" : "English")
                        .font(language.isDevanagari ? .wordDevanagari : .wordLatin)
                        .foregroundStyle(selected ? .white : WelcomeInk.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 13)
                        .background {
                            Capsule().fill(selected ? WelcomeInk.accent : .clear)
                        }
                        .overlay {
                            Capsule().stroke(selected ? .clear : WelcomeInk.ink.opacity(0.30), lineWidth: 1.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("welcomeLanguage-\(language.rawValue)")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}
