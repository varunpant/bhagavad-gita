//
//  WelcomeFit.swift
//  Gita
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - Fitting art to the slot it was given

/// Draws its content at the width it was given and, if the result is taller
/// than the slot, scales the whole thing down until it fits.
///
/// The welcome's art used to be handed a slot and `.clipped()`, which is right
/// for a screenshot that is *meant* to run off the foot of the page and wrong
/// for everything else. On an iPhone SE the art slot comes out around 240pt
/// against a verse pair that wants 430, so the second card — the English one,
/// on the page whose whole argument is "both scripts" — was cut away entirely.
/// The widgets on the last page went the same way.
///
/// Scaling rather than stepping down: the cards already have a `compact` mode
/// and it is not enough on the short screens, because what has to give there is
/// not one measurement but all of them at once. A picture that is smaller is
/// still the picture; half a picture is not.
///
/// Two passes, which is why the natural height goes through a preference: the
/// content is laid out at the slot's width to find the height it wants, and the
/// scale is applied on the pass after. The art is static per page, so the
/// second pass costs nothing anyone can see.
struct FitToSlot<Content: View>: View {
    let slot: CGSize
    @ViewBuilder var content: Content

    @State private var natural: CGFloat = 0

    private var scale: CGFloat {
        guard natural > 0, slot.height > 0 else { return 1 }
        return min(1, slot.height / natural)
    }

    var body: some View {
        content
            .frame(width: slot.width, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: NaturalHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(NaturalHeightKey.self) { natural = $0 }
            .scaleEffect(scale, anchor: .top)
            // The frame is the *scaled* height, so nothing below keeps a gap
            // for room the art no longer occupies.
            .frame(width: slot.width,
                   height: natural > 0 ? min(natural * scale, slot.height) : slot.height,
                   alignment: .top)
    }
}

private struct NaturalHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Measuring the words band

/// How many lines the welcome's own strings actually take at a given measure.
///
/// The words band is deliberately a fixed height, so that the rule, the kicker
/// and the art sit on the same line across all nine pages — but it was cut for
/// the worst case in both dimensions at once, two lines of title *and* three of
/// body, which no page reaches. That reserved 110-150pt of nothing above art
/// that was being clipped for want of exactly that height.
///
/// So it is measured instead: the tallest title and the tallest body among the
/// pages that will be shown, in the script they will be shown in. Still one
/// number for all nine pages — the datum survives — but the number is the truth
/// rather than a ceiling.
///
/// Main-actor, with a plain cache, exactly like `WelcomeVignette.aspects`: this
/// is asked for during layout and nothing else ever touches it. CoreText
/// measurement is not free enough to repeat per page per frame.
enum WelcomeType {

    /// Lines the longest of `strings` needs, floored at 1 and capped at `limit`.
    ///
    /// Falls back to the cap when the face cannot be resolved, which is the
    /// worst-case reservation this replaced: a missing font must never be able
    /// to make text disappear.
    static func lines(
        of strings: [String], family: String, size: CGFloat,
        lineHeight: CGFloat, width: CGFloat, limit: Int
    ) -> Int {
        guard width > 0, lineHeight > 0 else { return limit }

        let key = Key(family: family, size: size, width: width,
                      strings: strings.joined(separator: "\u{1}"))
        if let known = cache[key] { return min(known, limit) }

        guard let face = font(family: family, size: size) else { return limit }

        let tallest = strings.reduce(CGFloat(0)) { tallest, string in
            let bounds = (string as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: face], context: nil
            )
            return max(tallest, bounds.height)
        }

        // Rounded up, because a fragment of a second line is a second line.
        let needed = max(1, Int((tallest / lineHeight).rounded(.up)))
        cache[key] = needed
        return min(needed, limit)
    }

    private struct Key: Hashable {
        let family: String
        let size: CGFloat
        let width: CGFloat
        let strings: String
    }

    private static var cache: [Key: Int] = [:]

    #if canImport(UIKit)
    private static func font(family: String, size: CGFloat) -> UIFont? {
        // By family, not by PostScript name: `Font.custom` takes a family, and
        // the two differ for the variable faces this app bundles ("Inter"
        // against "Inter-Regular").
        let resolved = UIFont(descriptor: UIFontDescriptor(fontAttributes: [.family: family]),
                              size: size)
        // A family that is not installed resolves to the system face rather
        // than to nil, and measuring the wrong face is worse than not measuring
        // at all: it under-reserves, and the title is what gets clipped.
        guard resolved.familyName == family else { return nil }
        return resolved
    }
    #else
    private static func font(family: String, size: CGFloat) -> NSFont? {
        guard let resolved = NSFont(name: family, size: size),
              resolved.familyName == family else { return nil }
        return resolved
    }
    #endif
}
