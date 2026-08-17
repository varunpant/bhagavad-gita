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
    @Environment(Library.self) private var library
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
                .disabled(drawer.isOpen)
                // Ordered before the offset on purpose. `offset` moves a view
                // without changing its layout bounds, so an overlay added after
                // it still covers the original full-screen frame — including the
                // rail, whose taps it then swallowed. Applied first, the dismiss
                // layer travels with the page and leaves the rail alone.
                .overlay {
                    if drawer.isOpen {
                        Color.black.opacity(0.001)
                            .contentShape(.rect)
                            .onTapGesture { drawer.close() }
                            .accessibilityLabel("Close menu")
                            .accessibilityAddTraits(.isButton)
                    }
                }
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

            // One column, to the right of the rail, clipped to itself.
            //
            // The panel used to be a full-screen view with leading padding, so
            // sliding it moved that whole frame — and it swept across the rail
            // on its way in and out. Clipped to its own column it slides out
            // from under the rail instead, which is what the eye expects.
            ZStack {
                switch drawer.panel {
                case .settings:
                    SettingsView(showsChrome: false)
                        .transition(.move(edge: .leading))
                case .contents:
                    TableOfContentsView(
                        currentVerse: library.verse(id: settings.lastVerseID),
                        onSelect: { drawer.requestVerse($0.id) },
                        onClose: { drawer.panel = nil }
                    )
                    .transition(.move(edge: .leading))
                case .bookmarks:
                    BookmarksView(onSelect: { drawer.requestVerse($0.id) })
                        .transition(.move(edge: .leading))
                case .progress:
                    ReadingProgressView(onSelect: { drawer.requestVerse($0.id) })
                        .transition(.move(edge: .leading))
                case nil:
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .padding(.leading, railWidth)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(drawer.panel != nil)
            .zIndex(1)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.32), value: drawer.isOpen)
        .animation(reduceMotion ? nil : .snappy(duration: 0.30), value: drawer.panel)
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
            Spacer()

            panelButton(.contents)
            railButton("magnifyingglass", label: "Search") { drawer.search() }

            panelButton(.bookmarks)

            panelButton(.progress)

            // The script switch lives here rather than in the reader's header:
            // it changes the whole app, which is what the rail is for, and the
            // header is left to the verse.
            Button {
                Haptics.selection()
                settings.language = settings.language.toggled
            } label: {
                Text(settings.language.toggled.icon)
                    // Same size and weight as the symbols above it. SF Symbols
                    // are drawn to the cap height of text at the same point
                    // size, so matching the font is what makes the letter sit
                    // in the column at the same optical size as the glyphs.
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: railWidth, height: 52)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("languageToggle")
            .accessibilityLabel("Switch to \(settings.language.toggled.accessibilityName)")

            Spacer()

            // Settings sits at the foot rather than at the head. At the top it
            // was level with the status bar and the reader's own header, which
            // is the hardest place on the rail to see and the furthest from a
            // thumb; down here it is next to the only other control that is
            // about the app rather than about the book.
            panelButton(.settings)

            // A hairline between the two, so the gear reads as the last of the
            // controls rather than as part of the mark below it.
            Rectangle()
                .fill(.white.opacity(0.28))
                .frame(width: 22, height: 1)
                .padding(.vertical, 6)

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

    /// A rail button for a panel: its icon becomes a cross while it is open,
    /// and its label follows. All four derive from the destination.
    private func panelButton(_ destination: Drawer.Destination) -> some View {
        let isOpen = drawer.panel == destination
        return railButton(
            isOpen ? "xmark" : destination.symbol,
            label: isOpen ? "Close \(destination.rawValue)" : destination.noun
        ) {
            drawer.togglePanel(destination)
        }
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
