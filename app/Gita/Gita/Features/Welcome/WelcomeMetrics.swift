//
//  WelcomeMetrics.swift
//  Gita
//

import SwiftUI

// The welcome's layout system: every distance on the nine pages, read off one
// reference artboard. It lived at the foot of `WelcomeVignette.swift`, which is
// a file named after a picture — the last place anyone editing the guide's
// geometry would look.

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

    /// The same question as `tight`, asked of the slot the art was given
    /// rather than of the page. Both live here so the two cannot drift: a
    /// threshold in a view is a threshold nobody finds when the other moves.
    func isTightSlot(_ fitting: CGSize) -> Bool { tight || fitting.height < 620 }

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

    /// The long fade, for art that runs off the foot of the page.
    private static let bleedScrimReach: CGFloat = 170

    /// How far the wash reaches, which depends on what the page is showing.
    ///
    /// Derived from the same `art` case the art's own slot is derived from, so
    /// the two cannot disagree. It was a bare 170 in the view beside a separate
    /// helper answering "does this page bleed" — two places to keep in step,
    /// and the reason the wash once sat over the title page's language pills.
    func scrimReach(for art: WelcomeArt) -> CGFloat {
        if case .screen = art { return Self.bleedScrimReach }
        return Self.artClearance
    }

    /// The widest a screenshot is ever drawn on this page, in pixels.
    ///
    /// What `WelcomeArtStore` decodes to. At full size the ten shots come to
    /// 122 MB of bitmap for pictures drawn a third that wide.
    func artPixelWidth(scale: CGFloat) -> CGFloat {
        (pageWidth * (320 / Self.referenceWidth) * max(1, scale)).rounded()
    }

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
