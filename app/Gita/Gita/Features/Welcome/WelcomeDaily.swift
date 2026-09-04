//
//  WelcomeDaily.swift
//  Gita
//

import SwiftUI

/// The two things that reach the reader when the app is shut: the daily
/// reminder, and the widgets.
///
/// No device frame here, deliberately. A notification and a widget are not
/// screens — they are tiles that land on someone else's Home Screen — so they
/// sit directly on the page, the same call `design/media/README.md` makes for
/// the App Store panel. And no fabricated Home Screen behind them: a wallpaper
/// and a grid of other people's app icons would be the one invented thing on a
/// screen that is otherwise all the app's own output.
///
/// Drawn rather than captured because a widget render cannot be screenshotted
/// out of the extension by `WelcomeArtUITests`. Everything colour here comes
/// from `Brand`, and the ring is the same sweep `BrandRing` uses, so it cannot
/// drift from what the reader will actually pin.
struct WelcomeDaily: View {
    /// Which script the reader chose on page 1.
    ///
    /// Every other page's art follows it, and this one did not: the notification,
    /// the widget shloka, the week's heading and the streak line were all
    /// hard-coded Devanagari. A reader who chose English on page 1 was shown
    /// widgets in the script they had just declined — and it misrepresents the
    /// real ones, which follow `SharedProgress.isDevanagari`.
    let isDevanagari: Bool
    let metrics: WelcomeMetrics
    let fitting: CGSize

    /// The real widget aspect: a medium widget is 364 × 170 on a 6.9" phone.
    private static let mediumAspect: CGFloat = 364.0 / 170.0

    var body: some View {
        VStack(spacing: 14) {
            notification
            verseWidget
            progressWidget
        }
        .frame(width: max(0, min(fitting.width, metrics.artWidth)), alignment: .top)
    }

    // MARK: - The reminder

    /// A notification, at the hour the reader picks in Settings.
    ///
    /// Worth noting where this sits in the flow: the app must never ask for
    /// notification permission on launch — `DailyReminder.refillIfAuthorized`
    /// exists precisely so it does not — and this page, where the reader has
    /// just been told what a reminder is for, is the honest place to offer it.
    private var notification: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Brand.gradient)
                .frame(width: 36, height: 36)
                .overlay {
                    Text(verbatim: "ग")
                        .font(.custom(Fonts.devanagari, size: 22).weight(.light))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Gita")
                    .font(.custom(Fonts.latin, size: 12).weight(.bold))
                    .foregroundStyle(.black)
                Text(verbatim: isDevanagari ? "आज का श्लोक · २.४७" : "Today’s verse · 2.47")
                    .font(.custom(isDevanagari ? Fonts.devanagari : Fonts.latin, size: 12))
                    .foregroundStyle(.black.opacity(0.66))
            }

            Spacer(minLength: 0)

            Text(verbatim: "8:00")
                .font(.custom(Fonts.latin, size: 10))
                .foregroundStyle(.black.opacity(0.4))
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background { tile(cornerRadius: 20, washed: false) }
        .shadow(color: WelcomeInk.ink.opacity(0.11), radius: 20, y: 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - The widgets

    private var verseWidget: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(verbatim: isDevanagari ? "अध्याय २ · श्लोक ४७" : "CHAPTER 2 · VERSE 47")
                .font(.custom(isDevanagari ? Fonts.devanagari : Fonts.latin, size: 10).weight(.medium))
                .tracking(1.4)
                .foregroundStyle(.black.opacity(0.5))

            Text(verbatim: isDevanagari ? WelcomeSample.shlokaSa : WelcomeSample.shlokaEn)
                .font(.custom(isDevanagari ? Fonts.devanagari : Fonts.latin,
                              size: isDevanagari ? 17 : 15).weight(.light))
                .lineSpacing(isDevanagari ? 9 : 6)
                .foregroundStyle(.black)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            Text(verbatim: isDevanagari ? WelcomeSample.translationSa : WelcomeSample.translationEn)
                .font(.custom(isDevanagari ? Fonts.devanagari : Fonts.latin, size: 12).weight(.light))
                .lineSpacing(4)
                .foregroundStyle(.black.opacity(0.6))
                .lineLimit(2)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(Self.mediumAspect, contentMode: .fit)
        .background { tile(cornerRadius: 26) }
        .shadow(color: WelcomeInk.ink.opacity(0.11), radius: 20, y: 8)
        .accessibilityHidden(true)
    }

    private var progressWidget: some View {
        HStack(spacing: 22) {
            ring
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: isDevanagari ? "इस सप्ताह" : "THIS WEEK")
                    .font(.custom(isDevanagari ? Fonts.devanagari : Fonts.latin, size: 11).weight(.medium))
                    .tracking(1)
                    .foregroundStyle(.black.opacity(0.5))

                week

                Text(verbatim: isDevanagari ? "६ दिन की लय · २३ दिन पढ़े"
                                            : "6 day streak · 23 days read")
                    .font(.custom(isDevanagari ? Fonts.devanagari : Fonts.latin, size: 12).weight(.light))
                    .foregroundStyle(.black.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(Self.mediumAspect, contentMode: .fit)
        .background { tile(cornerRadius: 26) }
        .shadow(color: WelcomeInk.ink.opacity(0.11), radius: 20, y: 8)
        .accessibilityHidden(true)
    }

    /// The ramp swept round, with the ramp's own yellow as the track — the
    /// rule `Theme.track` states: a cold grey track beside a saffron arc reads
    /// as two designs, and what is left to read should look like the same book.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Brand.ramp[0].opacity(0.28), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            Circle()
                .trim(from: 0, to: 0.12)
                .stroke(Brand.ring, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(verbatim: isDevanagari ? "१२%" : "12%")
                    .font(.custom(isDevanagari ? Fonts.devanagari : Fonts.latin, size: 22).weight(.light))
                    .foregroundStyle(.black)
                Text(verbatim: isDevanagari ? "७०१ में से" : "of 701")
                    .font(.custom(isDevanagari ? Fonts.devanagari : Fonts.latin, size: 10).weight(.light))
                    .foregroundStyle(.black.opacity(0.5))
            }
        }
        .frame(width: 96, height: 96)
    }

    /// Seven days. Today takes the whole ramp; the rest take one colour from it
    /// at a tint — the same distinction `DayBar` draws.
    private var week: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array([0.42, 0.68, 0.26, 0.85, 0.50, 0.34, 1.0].enumerated()), id: \.offset) { index, fraction in
                let isToday = index == 6
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isToday
                          ? AnyShapeStyle(LinearGradient(colors: Brand.ramp,
                                                         startPoint: .bottom, endPoint: .top))
                          : AnyShapeStyle(Brand.ramp[1].opacity(0.55)))
                    .frame(height: max(3, 56 * fraction))
            }
        }
        .frame(height: 56)
    }

    /// A widget's own ground: white with a breath of saffron in the top
    /// trailing corner. `Theme.wash` keeps it under 12% — behind text, at
    /// widget size, anything stronger is a stain rather than a light.
    private func tile(cornerRadius: CGFloat, washed: Bool = true) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.white)
            .overlay {
                if washed {
                    // Scaled to the tile and at the strength `Theme.wash`
                    // actually uses. Both were wrong: 0.26 over a radius fixed
                    // at 190pt is a breath in the corner of a 364pt widget and
                    // a stain across the whole of a 240pt one, which is how
                    // these came out yellow on an iPad mini.
                    GeometryReader { proxy in
                        RadialGradient(colors: [Brand.ramp[0].opacity(0.11), .clear],
                                       center: .topTrailing, startRadius: 0,
                                       endRadius: proxy.size.width * 0.72)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(WelcomeInk.cardEdge, lineWidth: 1)
            }
    }
}
