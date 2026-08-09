//
//  GitaApp.swift
//  Gita
//

import SwiftUI

@main
struct GitaApp: App {
    /// Shared, injected rather than reached for through a singleton — this is
    /// what lets previews and tests run without the bundled database.
    @State private var library = Library()
    @State private var settings = Settings()
    @State private var semanticIndex = SemanticIndex()

    @Environment(\.colorScheme) private var colorScheme

    var body: some Scene {
        WindowGroup {
            ReaderView()
                .environment(library)
                .environment(settings)
                .environment(semanticIndex)
                .environment(\.theme, settings.theme.resolve(for: colorScheme))
                .dynamicTypeSize(settings.textSize.dynamicTypeSize)
        }
        #if os(macOS)
        .defaultSize(width: 720, height: 820)
        #endif
    }
}
