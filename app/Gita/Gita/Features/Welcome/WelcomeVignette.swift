//
//  WelcomeVignette.swift
//  Gita
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - A screen, in a device

/// A screenshot of the screen a welcome page is talking about.
///
/// Real captures of the running app, shot by `WelcomeArtUITests` in both
/// scripts and packed into the asset catalogue by `tools/make_welcome_art.py`.
/// They have to be reshot when the screens change — that is the price of
/// showing the reader the app rather than a drawing of it, and the same bargain
/// this repository already makes with `gita.sqlite` and the social cards.
///
/// **The whole screen, at its own aspect, in a frame.** The first version put a
/// 1320 × 2868 capture into a box 88% of the width by *half the height* with
/// `contentMode: .fill`, which on a phone is very nearly square: a tall screen
/// was cropped to a random horizontal band, and two four-stop dissolves then
/// took the edges off it. It read as a grey smudge rather than as a picture of
/// the app. Nothing is cropped here and nothing dissolves; the dark bezel is
/// what gives the shot an edge, and running off the bottom of the page is what
/// says the screen carries on past it.
struct WelcomeVignette: View {
    /// Asset name without the script suffix — `contents`, `search`, and so on.
    let art: String
    let isDevanagari: Bool
    let metrics: WelcomeMetrics
    /// The space the layout actually has left for the art, measured rather
    /// than guessed. See `WelcomeArtBox`.
    let fitting: CGSize

    /// The asset this page draws.
    var assetName: String { "welcome-\(art)-\(isDevanagari ? "sa" : "en")" }

    /// What the capture would be if nothing had been done to it, and the only
    /// thing left to fall back on if the asset cannot be measured.
    private static let captureAspect: CGFloat = 1320.0 / 2868.0

    /// The shot's own aspect, **read from the asset** rather than assumed.
    ///
    /// This was the constant above, which is the shape a capture has as it
    /// comes off the simulator — and not the shape of anything in the asset
    /// catalogue. `tools/make_welcome_art.py` trims the status bar off every
    /// shot and crops the rail off two of them, so what is actually bundled is
    /// 1260 × 2614 or 1104 × 2739. Neither is 1320 × 2868.
    ///
    /// That difference is not a letterbox. The glass below is given an
    /// explicit size with no `contentMode`, so a mismatch is a *stretch*: the
    /// appearance and progress panels were being drawn fourteen per cent wider
    /// than they are, which is why their rows read squat and their toggles
    /// read fat. Measuring the asset means any crop the tool applies — today's
    /// or tomorrow's — is drawn at its own proportions and needs no constant
    /// here kept in step with it.
    private var shotAspect: CGFloat { Self.aspect(of: assetName) }

    private static var aspects: [String: CGFloat] = [:]

    private static func aspect(of name: String) -> CGFloat {
        if let known = aspects[name] { return known }
        #if canImport(UIKit)
        let size = UIImage(named: name)?.size
        #else
        let size = NSImage(named: name)?.size
        #endif
        // The ratio, not the size: the catalogue reports a 3x asset at its own
        // scale on one platform and in points on the other, and only one of
        // those two numbers is the same on both.
        let measured = size.flatMap { $0.height > 0 ? $0.width / $0.height : nil }
        let value = measured ?? captureAspect
        aspects[name] = value
        return value
    }

    /// Bezel and corner, as shares of the device’s own width.
    ///
    /// The panel draws a 320pt device with a 7pt bezel and a 40pt corner. Held
    /// as constants those are right at exactly one size and wrong at every
    /// other: shrink the device to 190pt and the same seven points is half
    /// again as thick, while a 40pt radius on a 190pt box rounds the corners
    /// until the dark frame and the rounded shot inside it read as two heavy
    /// borders around a small picture. As shares they keep their proportion at
    /// any width.
    /// The panel’s own number: a 320pt device on a 440pt page, which leaves a
    /// margin of ground down either side rather than running edge to edge.
    /// Held as a share of the page, so a wider column gets a proportionally
    /// wider device rather than the same 320 marooned in the middle of it.
    private static let widthShare: CGFloat = 320 / WelcomeMetrics.referenceWidth

    private static let bezelShare: CGFloat = 7.0 / 320.0
    private static let radiusShare: CGFloat = 40.0 / 320.0

    /// The aspect of the whole device — shot plus bezel on all four sides.
    ///
    /// Not the same as the shot’s, and the difference is what crops the top
    /// line off a screenshot if the outer box is sized at `shotAspect` and the
    /// image inside told to fill it. Derived rather than typed: the glass is
    /// `1 - 2·bezelShare` of the width, so the whole thing is that much of the
    /// shot’s height plus the two bezels.
    private var frameAspect: CGFloat {
        1 / ((1 - 2 * Self.bezelShare) / shotAspect + 2 * Self.bezelShare)
    }

    /// How wide the device is drawn.
    ///
    /// Width first, always — the shot is a portrait phone, and its width is
    /// what decides whether the type inside it can be read at all. There is no
    /// height term here on purpose: the device is allowed to run off the foot
    /// of the page, so the slot's height caps what is *drawn*, never what is
    /// drawn *at*. Sizing the width to fit between the body text and the button
    /// is what made it small — on a 6.9" phone that came out a 190pt phone
    /// drawn inside a 440pt one, all bezel and no screen.
    private var width: CGFloat {
        max(0, min(fitting.width, metrics.artWidth, metrics.pageWidth * Self.widthShare))
    }

    var body: some View {
        let full = width / frameAspect
        device(width: width, height: full)
            // Reports the slot it was given, and draws past it, where the
            // controls' scrim fades it out instead of a hard edge cutting it.
            .frame(width: width,
                   height: max(0, min(full, fitting.height)),
                   alignment: .top)
            .accessibilityHidden(true)
    }

    /// The shot, its bezel and its shadow, at an explicit size.
    ///
    /// Explicit rather than `.aspectRatio(_:contentMode:)` under a flexible
    /// frame, which does not hold — the frame stretches the composed device,
    /// bezel and all, and the shot inside comes out the wrong shape.
    private func device(width: CGFloat, height: CGFloat) -> some View {
        let bezel = max(3, width * Self.bezelShare)
        let outer = width * Self.radiusShare
        // No `contentMode` — the glass is given the exact size the shot’s own
        // aspect asks for, so there is nothing left to fill or fit.
        return Image(assetName)
            .resizable()
            .frame(width: max(0, width - bezel * 2), height: max(0, height - bezel * 2))
            .clipShape(RoundedRectangle(cornerRadius: max(2, outer - bezel), style: .continuous))
            .padding(bezel)
            .background {
                RoundedRectangle(cornerRadius: outer, style: .continuous)
                    .fill(Color(.sRGB, red: 0x1A / 255, green: 0x14 / 255, blue: 0x12 / 255, opacity: 1))
            }
            .shadow(color: WelcomeInk.ink.opacity(0.20), radius: 30, y: 14)
    }
}

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
    private var compact: Bool { metrics.tight || fitting.height < 620 }

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
nonisolated enum WelcomeSample {
    struct Gloss: Sendable { let word: String; let gloss: String }

    /// The first line of the shloka. `gita.sqlite` holds both lines and no
    /// danda — punctuation is presentation, added back by the app — so the
    /// danda here is the app's, and `WelcomeSampleTests` compares without it.
    static let shlokaSa = "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।"
    static let shlokaEn = "karmaṇyevādhikāraste mā phaleṣu kadācana"

    /// Each of these is the opening of what the reader will actually meet at
    /// 2.47 — the first sentence, not a paraphrase of it. They used to be
    /// neither: "You have a right to your action alone, never to its fruits."
    /// is a better line than the corpus has and is not in the corpus, so a
    /// reader who followed the guide to the verse met different words.
    static let translationSa = "तुम्हारा अधिकार केवल कर्म करने में है, उसके फलों में कभी नहीं।"
    static let translationEn = "You have a right to perform your prescribed duty, but you are not entitled to the fruits of action."

    static let meaningSa = "यह श्लोक निष्काम कर्मयोग का मूल सिद्धांत प्रस्तुत करता है।"
    static let meaningEn = "This verse presents the core principle of Nishkama Karma Yoga or selfless action."

    /// The first five glosses, verbatim from `word_by_word_*`.
    static let wordsSa: [Gloss] = [
        Gloss(word: "कर्मणि", gloss: "कर्म में"),
        Gloss(word: "एव", gloss: "ही"),
        Gloss(word: "अधिकारः", gloss: "अधिकार"),
        Gloss(word: "ते", gloss: "तुम्हारा"),
        Gloss(word: "मा", gloss: "नहीं"),
    ]

    static let wordsEn: [Gloss] = [
        Gloss(word: "karmaṇi", gloss: "in prescribed duty"),
        Gloss(word: "eva", gloss: "only"),
        Gloss(word: "adhikāraḥ", gloss: "right"),
        Gloss(word: "te", gloss: "your"),
        Gloss(word: "mā", gloss: "never"),
    ]
}

// MARK: - Metrics

/// Everything the welcome sizes from, derived from the page it is actually on.
///
/// **One composition, at every size.** There used to be three — stacked,
/// headed, and a two-column split — chosen from the page's shape, and the
/// reference has only ever had one: nine portrait pages, words above art above
/// controls. Columns were an invention of the implementation, not of the
/// design, and they meant an iPad and a Mac were laid out by code no phone ever
/// ran. The page now draws the same thing everywhere and simply centres it,
/// which is the only version anyone has actually drawn.
///
/// **Three datums, and all of them measured from the screen.** The rule sits a
/// fixed distance below the top edge, the art begins at a line that is the same
/// on all nine pages, and the button sits a fixed distance above the bottom
/// edge. Everything that has to give gives in between. Measuring from the safe
/// area instead — which is what this did — makes each of those distances a
/// different number on every device: 72 below the status bar is 134 from the
/// top of a 6.9" phone and 92 on an SE, so the same layout arrives a title
/// lower on one than the other.
struct WelcomeMetrics: Equatable, Sendable {
    /// The whole page, safe areas included — the artboard's own frame.
    let size: CGSize
    /// What the system keeps for itself at either end of that page. The page
    /// draws through both and steps around them where it must.
    var safeTop: CGFloat = 0
    var safeBottom: CGFloat = 0
    /// Which script the page is set in. It belongs here because it changes a
    /// *measurement*, not just a face: Devanagari is set two points larger on
    /// the same page and carries matras above and below its line, so the band
    /// reserved for a title is taller in one script than the other. Reserving
    /// the Devanagari height for a Latin page is what put the art 48 points
    /// below the line the reference draws it on.
    var devanagari: Bool = false

    // MARK: - The reference

    /// The artboard is 440 x 956, and every constant below is read off it.
    static let referenceWidth: CGFloat = 440

    /// The widest the column ever draws, whatever the window does.
    ///
    /// A Mac window has no upper bound and an iPad 13" is 1024pt across; a
    /// single column let loose in either sets a 44pt heading at a measure no
    /// one can read and floats a phone-shaped screenshot in an acre of ground.
    /// Past this the page stops growing and centres — the same discipline
    /// `ReaderView` applies to the verse itself.
    static let maxPageWidth: CGFloat = 560

    /// The page's own width, capped. Every measure below comes out of this.
    var pageWidth: CGFloat { min(size.width, Self.maxPageWidth) }

    /// How far the page is from the reference's own width, for the handful of
    /// things that are shares rather than steps.
    var scale: CGFloat { pageWidth / Self.referenceWidth }

    /// The reference's 32pt margin, held as a share so a 560pt column gets a
    /// proportional one rather than the same 32 it would look pinched in.
    var horizontalPadding: CGFloat {
        min(56, max(24, (pageWidth * 32 / Self.referenceWidth).rounded()))
    }

    /// The width inside the margins.
    var content: CGFloat { pageWidth - horizontalPadding * 2 }

    /// A page too short to spend the reference's air on. An SE is 667pt tall:
    /// 72 points of nothing before the page has said anything is a tenth of it.
    var tight: Bool { size.height < 820 }

    /// A page with room to set the opening larger. Not a device check and not
    /// a size class — just whether this column is nearer 560 than 440.
    var roomy: Bool { pageWidth >= 500 }

    // MARK: - The top datum

    /// The reference draws the rule 72 points below the top of the **screen**.
    private static let designTop: CGFloat = 72
    /// And never closer than this to the clock, on a device whose inset is
    /// deeper than the reference's.
    private static let statusClearance: CGFloat = 10

    var topPadding: CGFloat {
        max(tight ? 48 : Self.designTop, safeTop + Self.statusClearance)
    }

    /// Where the close button's 44pt tap target begins.
    ///
    /// Levelled with the page's own top line rather than pinned to the safe
    /// area: its centre sits on the marigold rule above the kicker, so the
    /// button and the first thing the page says share a datum.
    ///
    /// It used to be `safeTop + 6`, which was fine until the status bar was
    /// hidden app-wide — with no status bar, `safeAreaInsets.top` reports **0**
    /// on a notched phone, and `6` put the button up level with the Dynamic
    /// Island, floating above everything else on the page. The lesson is that
    /// the top inset is a fact about the *system's* furniture, and this button
    /// belongs to the page's.
    ///
    /// Floored so that a device which does report an inset is still cleared.
    var closeTop: CGFloat {
        max(topPadding - (Self.closeButton - 3) / 2, safeTop + 6)
    }

    /// The close button's tap target, which is Apple's minimum and not a size
    /// chosen here.
    static let closeButton: CGFloat = 44

    // MARK: - The bottom datum

    static let dotsHeight: CGFloat = 6
    static let controlsGap: CGFloat = 20
    static let buttonHeight: CGFloat = 56
    /// Air between whatever the art ends with and the dots.
    static let controlsClearance: CGFloat = 22

    /// The reference puts the button 34 points above the foot of the screen,
    /// which on a phone is inside the home indicator. This is that distance
    /// plus the indicator's own room.
    private static let designBottom: CGFloat = 46
    /// And never less than this above the safe area, whatever the device
    /// reserves down there.
    private static let bottomFloor: CGFloat = 16

    /// How far above the safe area the button sits — computed so that its
    /// distance from the screen's own bottom edge is the same on a phone with a
    /// home indicator, an iPad, and a Mac window, which is what "constant" has
    /// to mean when the inset is a different number on each.
    var controlsBottom: CGFloat { max(Self.designBottom - safeBottom, Self.bottomFloor) }

    /// The whole strip the controls own, measured up from the foot of the page.
    /// Derived from the parts rather than typed as one number, so moving the
    /// button moves the floor the art is sized against with it.
    var controlsHeight: CGFloat {
        safeBottom + controlsBottom + Self.buttonHeight
            + Self.controlsGap + Self.dotsHeight + Self.controlsClearance
    }

    /// How far up the page the haze behind the controls reaches.
    ///
    /// Taller than the strip it is there for, and by a good margin. The scrim
    /// has two jobs — fade a screenshot that is running off the foot of the
    /// page, and give the dots and the button a ground to be read against —
    /// and a scrim that only covers what the controls occupy does neither: it
    /// arrives as a horizontal edge across the art with the button sitting on
    /// it, which is how a contents grid ended up legible right up to the word
    /// "Next". The fade has to start well above anything it is protecting.
    /// `reach` is how far above the controls the fade starts, and it differs
    /// by page: art that runs off the foot needs a long fade to dissolve into,
    /// and the title page — whose language pills sit just above the button —
    /// needs the wash nowhere near them.
    func scrimHeight(reach: CGFloat) -> CGFloat { controlsHeight + reach }

    /// Where the wash reaches full opacity, as a fraction of `scrimHeight`,
    /// measured down from its top: the top of the dots.
    func scrimOpaque(reach: CGFloat) -> CGFloat {
        let height = scrimHeight(reach: reach)
        let dotsTop = safeBottom + controlsBottom + Self.buttonHeight
            + Self.controlsGap + Self.dotsHeight
        return max(0.35, min(0.85, (height - dotsTop) / height))
    }

    // MARK: - Type

    var titleSize: CGFloat {
        let base: CGFloat
        if content >= 640 { base = 44 }
        else if content >= 430 { base = 36 }
        else { base = 32 }
        return tight ? base - 4 : base
    }

    var bodySize: CGFloat {
        if titleSize >= 44 { return 25 }
        if titleSize >= 34 { return 21 }
        return tight ? 17 : 19
    }

    var kickerSize: CGFloat { titleSize >= 36 ? 14 : 12 }

    // MARK: - The words band

    /// The band the rule, the kicker and the title always occupy.
    ///
    /// Fixed, and cut for the longest of them — two lines of title — so that a
    /// one-line title and a two-line one leave the body and the art in exactly
    /// the same place. Without this the carousel jumped: the rule sat still
    /// while everything under it moved a line up or down with every swipe.
    ///
    /// The multipliers are line heights, not point sizes, and each script gets
    /// its own: 1.19 is what Georgia actually sets a 32pt title at, and the
    /// reference is drawn in it. Devanagari is measured two points larger and
    /// at 1.42, which is the room its matras need.
    var titleLine: CGFloat {
        devanagari ? ((titleSize + 2) * 1.42).rounded(.up)
                   : (titleSize * 1.19).rounded(.up)
    }

    var bodyLine: CGFloat {
        devanagari ? ((bodySize + 1) * 1.55).rounded(.up)
                   : (bodySize * 1.42).rounded(.up)
    }

    var headingHeight: CGFloat {
        let rule: CGFloat = 3 + 20
        let kicker = (kickerSize * 1.5).rounded(.up) + 12
        return rule + kicker + titleLine * CGFloat(titleLines)
    }

    /// How many lines the longest **title** actually takes at this measure, in
    /// this script — one number for all nine pages, so the datum holds.
    ///
    /// This used to be a flat 2, and with `bodyHeight`'s flat 3 it reserved
    /// 110-150pt more than any page sets on a 6.9" phone. That hole sat
    /// directly above art that was being clipped for want of the same height.
    /// Capped at 2 so a face that will not resolve reserves what it always did.
    var titleLines: Int {
        WelcomeType.lines(
            of: WelcomePage.all.map { $0.title(isDevanagari: devanagari) },
            family: devanagari ? Fonts.devanagari : Fonts.latin,
            size: devanagari ? titleSize + 2 : titleSize,
            lineHeight: titleLine, width: content, limit: 2
        )
    }

    /// The body's own band, measured the same way. Three lines is what the
    /// longest page — progress and goals — runs to on a narrow phone; wider
    /// columns set it in two, and used to be given three anyway.
    var bodyHeight: CGFloat { bodyLine * CGFloat(bodyLines) }

    var bodyLines: Int {
        WelcomeType.lines(
            of: WelcomePage.all.map { $0.body(isDevanagari: devanagari) },
            family: devanagari ? Fonts.devanagari : Fonts.latin,
            size: devanagari ? bodySize + 1 : bodySize,
            lineHeight: bodyLine, width: content, limit: 3
        )
    }

    /// Heading plus body: what every page spends above its art.
    var wordsHeight: CGFloat { headingHeight + 12 + bodyHeight }

    // MARK: - The art

    /// How far the art keeps clear of the controls' wash, and how far that wash
    /// reaches on a page whose art does not bleed. One number, because they are
    /// the same distance seen from either side.
    static let artClearance: CGFloat = 40

    /// The gap the reference leaves between the body and the art.
    static let artGap: CGFloat = 20

    /// Where the art begins — the same line on all nine pages, because
    /// everything above it is a constant.
    var artTop: CGFloat { topPadding + wordsHeight + Self.artGap }

    /// How wide the art may be: the whole measure. Cards and widgets are text
    /// and want every point of it; a device shot takes its own narrower share
    /// in `WelcomeVignette`.
    var artWidth: CGFloat { content }

    /// The height the art gets when it has to stay clear of the controls —
    /// everything between the art's own line and the top of the button's strip.
    /// This is the number whose absence was behind every "it runs under the
    /// button": the art used to be handed `maxHeight: .infinity` and sized
    /// itself against a page that had already spent a third of its height.
    var artHeight: CGFloat { max(0, size.height - artTop - controlsHeight) }

    /// And the height it gets when it may run off the foot of the page, which
    /// is what a screenshot does: the device begins below the words and carries
    /// on past the edge, where the controls' scrim fades it out instead of a
    /// hard line cutting it.
    var artBleedHeight: CGFloat { max(0, size.height - artTop) }
}
