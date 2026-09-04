//
//  BrandToggleStyle.swift
//  Gita
//

import SwiftUI

/// A switch that wears the brand ramp instead of a flat tint.
///
/// **Why a style and not `.tint`.** `.tint(_:)` takes a `Color`, and a colour
/// is the one thing a gradient is not. There is no supported way to hand a
/// `ShapeStyle` to a system switch, so the track has to be drawn here.
///
/// **Why the accessibility representation matters more than the drawing.** A
/// hand-drawn track is a shape with a tap gesture, and to VoiceOver and to
/// XCUITest that is not a switch: `app.switches["toggleWordByWord"]` stops
/// matching, and three UI test suites drive the settings that way.
/// `accessibilityRepresentation` hands the accessibility tree a real `Toggle`
/// bound to the same value, so what is drawn changes and what is *announced
/// and automated* does not.
struct BrandToggleStyle: ToggleStyle {
    let theme: Theme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The system switch's own metrics. Matched rather than invented, so a
    /// row of these lines up with any control this app has not replaced.
    private static let trackWidth: CGFloat = 51
    private static let trackHeight: CGFloat = 31
    private static let knobInset: CGFloat = 2

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 8)
            track(configuration)
        }
        .contentShape(.rect)
        .onTapGesture { toggle(configuration) }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }

    private func track(_ configuration: Configuration) -> some View {
        let knob = Self.trackHeight - Self.knobInset * 2

        return ZStack(alignment: configuration.isOn ? .trailing : .leading) {
            Capsule()
                .fill(theme.divider)
                .overlay {
                    // The gradient is laid over the off state rather than
                    // swapped for it, so the fade runs both ways at the same
                    // speed. Two fills crossing over produced a flicker at the
                    // midpoint where neither was opaque.
                    Capsule()
                        .fill(theme.switchGradient)
                        .opacity(configuration.isOn ? 1 : 0)
                }

            Circle()
                .fill(.white)
                // A hairline, because a white knob on the ramp's yellow end has
                // very little to separate it from the track.
                .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                .frame(width: knob, height: knob)
                .padding(.horizontal, Self.knobInset)
        }
        .frame(width: Self.trackWidth, height: Self.trackHeight)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: configuration.isOn)
    }

    private func toggle(_ configuration: Configuration) {
        // The feedback `Haptics.selection` was written for: "a setting changed,
        // a toggle flipped". A system switch fires nothing, so until now the
        // only settings that spoke back were the ones behind a button.
        Haptics.selection()
        configuration.isOn.toggle()
    }
}
