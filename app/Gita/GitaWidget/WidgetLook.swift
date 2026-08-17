//
//  WidgetLook.swift
//  GitaWidget
//

import SwiftUI
import WidgetKit

/// How a widget picks its colours and its type.
///
/// The app's `Theme` and `Brand` are compiled into the extension rather than
/// copied into it, so a widget is the same four themes and the same saffron as
/// the app — change the ramp once and the icon, the splash and the widgets all
/// move together.
///
/// Theme is *chosen* in the app, so it arrives through the App Group like
/// everything else. When the reader has not pinned one, the widget falls back to
/// the system appearance, which is what "System" means everywhere else.
extension Theme {
    static func forWidget(_ preference: String?, colorScheme: ColorScheme) -> Theme {
        switch preference {
        case "light": .light
        case "sepia": .sepia
        case "dark": .dark
        default: resolved(for: colorScheme)
        }
    }

    /// The unfilled part of a ring. A tint of the ramp's own yellow rather than
    /// grey: a cold grey track beside a saffron arc reads as two designs, and
    /// what is left to read should look like the same book.
    var track: Color {
        Brand.ramp[0].opacity(self == .dark ? 0.22 : 0.28)
    }

    /// A breath of saffron in the corner, so a widget reads as this app's rather
    /// than as a system panel. Kept under 12% — behind text, at widget size,
    /// anything stronger is a stain rather than a light.
    var wash: RadialGradient {
        RadialGradient(
            colors: [Brand.ramp[0].opacity(self == .dark ? 0.16 : 0.11), .clear],
            center: .topTrailing,
            startRadius: 0,
            endRadius: 190
        )
    }
}

/// Widget type, which is not reading type.
///
/// `Font+Roles` is sized for a page held at reading distance; a widget is
/// glanced at from across a desk, so it wants its own scale. The faces are the
/// same two the app reads in — Kohinoor for Devanagari, Georgia for Latin — so
/// the family still holds.
extension Font {
    static func widgetNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .serif)
    }

    static func widgetDevanagari(_ size: CGFloat) -> Font {
        .custom("KohinoorDevanagari-Light", size: size)
    }

    static func widgetSerif(_ size: CGFloat) -> Font {
        .custom("Georgia", size: size)
    }

    /// Section labels: small, spaced, upper case. The one place the widget does
    /// not follow the reading language in *face*, because Devanagari has no
    /// upper case — the Devanagari label uses Kohinoor at the same size instead.
    static let widgetLabel = Font.system(size: 10, weight: .semibold)
}

/// A ring filled with the brand ramp.
///
/// Drawn rather than `Gauge`: a gauge on iOS renders its own accent, its own
/// label placement and its own end caps, none of which are this app's.
struct BrandRing: View {
    let completion: Double
    let theme: Theme
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                // A hair of fill even at zero, so the ring reads as a ring the
                // reader has not started rather than as a ring that is broken.
                .trim(from: 0, to: max(0.004, completion))
                .stroke(Brand.ring, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// One day's reading, as a bar. The chart owns the scale — a bar cannot know
/// how tall it should be without knowing the busiest day beside it.
struct DayBar: View {
    let fraction: Double
    let theme: Theme
    let isToday: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isToday
                          ? AnyShapeStyle(LinearGradient(colors: Brand.ramp,
                                                         startPoint: .bottom, endPoint: .top))
                          : AnyShapeStyle(Brand.ramp[1].opacity(0.55)))
                    // A day with nothing read still shows a sliver, so the row
                    // reads as seven days rather than as four.
                    .frame(height: max(3, geometry.size.height * fraction))
            }
        }
    }
}
