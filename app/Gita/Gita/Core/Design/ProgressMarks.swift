//
//  ProgressMarks.swift
//  Gita
//

import SwiftUI

// The two marks that draw progress, shared by the app and the widget target.
//
// They lived in `GitaWidget/WidgetLook.swift`, which made them widget-only —
// and so the app drew its own ring separately, with `theme.divider` for the
// track: a cold grey beside a saffron arc, which is the exact thing the
// comment on `Theme.track` argues against. The same number was two designs
// depending on where you looked at it.
//
// `Theme.track` and `Theme.wash` moved to `Theme.swift` for the same reason:
// that file is already compiled into both targets, so the widget's colours
// were never the widget's — only their address was.

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
