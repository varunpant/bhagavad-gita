//
//  GitaApp.swift
//  Gita
//

import SwiftUI

@main
struct GitaApp: App {
    /// Shared, injected rather than reached for through a singleton — this is
    /// what lets previews and tests run without the bundled database.
    /// Opened once and shared, rather than three times over in three
    /// initialisers.
    private static let store = UserDatabase.shared

    /// Both faces are bundled rather than system, so nothing can draw in them
    /// until they are registered. Done here, in `init`, because a `.task` on
    /// the root view runs *after* the first layout — long enough for the
    /// splash and the first verse to be composed in the system face and then
    /// reflowed once the real one arrives.
    init() {
        Fonts.register()
    }

    @State private var library = Library()
    @State private var settings = Settings(store: Self.store)
    @State private var semanticIndex = SemanticIndex()
    @State private var drawer = Drawer()
    @State private var bookmarks = Bookmarks(store: Self.store)
    @State private var progress = ReadingProgress(store: Self.store)

    @Environment(\.colorScheme) private var colorScheme

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(settings)
                .environment(semanticIndex)
                .environment(drawer)
                .environment(bookmarks)
                .environment(progress)
                .environment(\.theme, settings.theme.resolve(for: colorScheme))
                .dynamicTypeSize(settings.textSize.dynamicTypeSize)
                // Without this the app's own colours follow the chosen theme but
                // every system control — Form rows, pickers, toggles, the sheet
                // background — stays on the device appearance, so picking Dark
                // left half the UI light.
                .preferredColorScheme(settings.theme.resolve(for: colorScheme).colorScheme)
        }
        #if os(macOS)
        // Wide enough that the rail sits at the left edge with the page beside
        // it rather than under it, and the reader's measure is centred in real
        // margins rather than filling a narrow window edge to edge. 720 was a
        // phone-shaped window on a desk: the rail took a tenth of it, and the
        // column had nowhere to be centred.
        //
        // The measure itself stays capped — see `ReaderView` — so a wider
        // window buys margin, not longer lines. That is the point: this is the
        // one screen where a reader can put the book down in the middle of
        // their desk and leave it open.
        .defaultSize(width: 1100, height: 860)
        #endif
    }
}
