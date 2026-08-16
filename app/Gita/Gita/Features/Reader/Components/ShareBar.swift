//
//  ShareBar.swift
//  Gita
//

import SwiftUI

/// Two ways to send a verse to someone: as a link, or as a picture.
///
/// Sits directly under the shloka, centred, small and low-contrast — near the
/// thing it acts on, but never competing with it. Shown only when the reader
/// asks for it in Settings.
struct ShareBar: View {
    let verse: Verse
    let language: ReadingLanguage

    @Environment(\.theme) private var theme

    /// Rendered on demand rather than up front: 701 cards eagerly rendered
    /// would be an enormous waste for the one or two anybody actually sends.
    @State private var card: Image?

    var body: some View {
        HStack(spacing: 4) {
            ShareLink(
                item: verse.shareURL,
                subject: Text(verse.shareTitle(for: language)),
                message: Text(verse.shareText(for: language))
            ) {
                icon("link")
            }
            .accessibilityIdentifier("shareLink")
            .accessibilityLabel("Share a link to this verse")

            if let card {
                ShareLink(
                    item: card,
                    preview: SharePreview(verse.shareTitle(for: language), image: card)
                ) {
                    icon("photo")
                }
                .accessibilityIdentifier("shareImage")
                .accessibilityLabel("Share this verse as an image")
            }
        }
        .buttonStyle(.plain)
        .task(id: verse.id) {
            // Re-rendered per verse and per language, which `id:` covers by way
            // of the reader rebuilding the page when the script changes.
            card = ShareCard.render(verse: verse, language: language)
        }
    }

    private func icon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .light))
            .foregroundStyle(theme.textSecondary)
            .frame(width: 44, height: 34)
            .contentShape(.rect)
    }
}
