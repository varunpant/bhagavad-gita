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
        .defaultSize(width: 720, height: 820)
        #endif
    }
}
