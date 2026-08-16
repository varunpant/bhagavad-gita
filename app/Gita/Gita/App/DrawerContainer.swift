//
//  DrawerContainer.swift
//  Gita
//

import SwiftUI

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
    @Environment(Settings.self) private var settings
    @Environment(Bookmarks.self) private var bookmarks
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let railWidth: CGFloat = 72
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Behind everything, so the rounded corners of the open page reveal
            // the reading background rather than the bare window, which showed
            // as grey rectangles above and below the page. The rail is the only
            // coloured surface; the space around the page stays the theme's.
            theme.background.ignoresSafeArea()

            rail

            // Offset only — no clip. Clipping the page meant animating how much
            // of it was cut, and because the page paints past its own bounds to
            // fill the status bar, that cut travelled visibly across the top as
            // the rail opened. Nothing is gained by it: a white page on a white
            // background has no corner to see.
            content
                .offset(x: drawer.isOpen ? railWidth : 0)
                // No drop shadow: cast around the whole page it smudged grey
                // onto the background above and below the rounded corners. The
                // separation the rail needs is only along the page's left edge,
                // so that is the only place anything is drawn.
                .overlay(alignment: .leading) {
                    if drawer.isOpen {
                        LinearGradient(
                            colors: [.black.opacity(0.10), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 12)
                        .allowsHitTesting(false)
                    }
                }
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
            // Sits on the same centre line as the reader's menu glyph: the
            // header pads 10pt and centres a 32pt button, putting its middle
            // 26pt below the safe area, which is exactly the middle of this
            // 52pt button with no padding above it.
            railButton("gearshape", label: "Settings") { drawer.choose(.settings) }

            Spacer()

            railButton("list.bullet", label: "Contents") { drawer.choose(.contents) }
            railButton("magnifyingglass", label: "Search") { drawer.search() }

            // Acts on the verse being read rather than opening a list. The
            // reader saves its position on every move, so that is where the
            // rail learns which verse "this one" is without reaching into it.
            railButton(
                bookmarks.contains(settings.lastVerseID) ? "bookmark.fill" : "bookmark",
                label: bookmarks.contains(settings.lastVerseID) ? "Remove bookmark" : "Bookmark this verse"
            ) {
                let added = bookmarks.toggle(settings.lastVerseID)
                added ? Haptics.pageTurn() : Haptics.selection()
            }

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
