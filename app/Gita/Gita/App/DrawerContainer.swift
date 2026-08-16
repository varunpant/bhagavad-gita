//
//  DrawerContainer.swift
//  Gita
//

import SwiftUI

/// The shape the page is clipped to.
///
/// Rounded at the screen edges while the rail is open, and **bled well past the
/// top and bottom while closed**. The reader paints its background beyond its
/// own bounds so it fills the status bar and home-indicator areas; clipping to
/// those bounds would slice that background off and let the rail's gradient show
/// through at the top-left and bottom-left corners. Extending the clip past the
/// screen means the closed state clips nothing at all.
private struct PageClip: Shape {
    var radius: CGFloat
    var bleed: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(radius, bleed) }
        set { radius = newValue.first; bleed = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect.insetBy(dx: 0, dy: -bleed),
             cornerRadius: radius,
             style: .continuous)
    }
}

/// A permanent left rail that the content slides off to reveal.
///
/// The content is **offset**, never re-laid-out: opening the rail must not
/// re-wrap a single line of the verse. Text that runs past the right edge is
/// clipped by the screen, which is the point — the page moves aside rather than
/// reflowing around the rail.
///
/// The rail keeps its marigold gradient in every theme. It is the one piece of
/// brand in the running app, and it is deliberate rather than a stray colour.
struct DrawerContainer<Content: View>: View {
    @Environment(Drawer.self) private var drawer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let railWidth: CGFloat = 72
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Behind everything, so the rounded corners of the open page reveal
            // the brand ground rather than the bare window — which showed as
            // grey rectangles above and below the page.
            Brand.gradient.ignoresSafeArea()

            rail

            content
                .offset(x: drawer.isOpen ? railWidth : 0)
                .clipShape(PageClip(radius: drawer.isOpen ? 20 : 0,
                                    bleed: drawer.isOpen ? 0 : 240))
                .shadow(color: .black.opacity(drawer.isOpen ? 0.18 : 0), radius: 18, x: -6)
                // While the rail is open the page is a dismiss target, not a
                // reader: a stray tap should close, never turn a page.
                .disabled(drawer.isOpen)
                .overlay {
                    if drawer.isOpen {
                        Color.black.opacity(0.001)
                            .contentShape(.rect)
                            .onTapGesture { drawer.close() }
                            .accessibilityLabel("Close menu")
                            .accessibilityAddTraits(.isButton)
                    }
                }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.32), value: drawer.isOpen)
        .gesture(edgeDrag)
    }

    /// Drag in from the left edge to open, and back to close — the gesture
    /// people already expect from a drawer, so the button is not the only way.
    private var edgeDrag: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                guard abs(horizontal) > vertical else { return }   // ignore a scroll

                if horizontal > 40, value.startLocation.x < 40 {
                    drawer.open()
                } else if horizontal < -40, drawer.isOpen {
                    drawer.close()
                }
            }
    }

    // MARK: - Rail

    private var rail: some View {
        VStack(spacing: 0) {
            railButton("gearshape", label: "Settings") { drawer.choose(.settings) }
                .padding(.top, 8)

            Spacer()

            railButton("list.bullet", label: "Contents") { drawer.choose(.contents) }
                .padding(.bottom, 28)
            railButton("magnifyingglass", label: "Search") { drawer.choose(.contents) }

            Spacer()

            // The mark closes the rail: the bottom of the rail is where a thumb
            // rests, and it needs something to do.
            Button { drawer.close() } label: {
                Text(verbatim: "ग")
                    .font(.custom("KohinoorDevanagari-Light", size: 30))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: railWidth, height: 52)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close menu")
            .padding(.bottom, 12)
        }
        .frame(width: railWidth)
        .frame(maxHeight: .infinity)
        // The gradient bleeds into the status bar and the home indicator; the
        // icons stay inside the safe area, or the top one collides with the clock.
        .background(Brand.gradient.ignoresSafeArea())
        .accessibilityHidden(!drawer.isOpen)
    }

    private func railButton(
        _ symbol: String, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white)
                .frame(width: railWidth, height: 52)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

}
