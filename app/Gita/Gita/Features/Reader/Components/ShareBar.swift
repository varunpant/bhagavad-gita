//
//  ShareBar.swift
//  Gita
//

import SwiftUI

/// One share icon under the verse, opening a small popup with the two ways to
/// send it: as an app link, or as a picture.
///
/// A single icon rather than a row of them — the reader knows what a share
/// glyph does, and the choice between link and image belongs one level in
/// rather than on the reading page.
struct ShareBar: View {
    let verse: Verse
    let language: ReadingLanguage

    @Environment(\.theme) private var theme

    @State private var showingOptions = false

    private var isDevanagari: Bool { language == .sanskrit }

    var body: some View {
        Button {
            showingOptions = true
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 44, height: 40)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("shareButton")
        .accessibilityLabel("Share this verse")
        .popover(isPresented: $showingOptions) {
            options
                // Keeps it a popup on iPhone too — without this, a compact
                // width promotes a popover to a full sheet, which is far more
                // ceremony than two choices deserve.
                .presentationCompactAdaptation(.popover)
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShareLink(
                item: verse.shareURL,
                subject: Text(verse.shareTitle(for: language)),
                message: Text(verse.shareText(for: language))
            ) {
                row(
                    "link",
                    title: isDevanagari ? "कड़ी" : "Link",
                    detail: isDevanagari ? "यह श्लोक गीता में खोलती है" : "Opens this verse in Gita"
                )
            }
            .accessibilityIdentifier("shareLink")

            Divider()

            // A `Transferable` rather than a rendered `Image` held in state:
            // the row is then never conditional, and the card is drawn only if
            // the reader actually picks it.
            ShareLink(
                item: VerseCard(verse: verse, language: language),
                preview: SharePreview(verse.shareTitle(for: language))
            ) {
                row(
                    "photo",
                    title: isDevanagari ? "चित्र" : "Image",
                    detail: isDevanagari ? "श्लोक चित्र के रूप में" : "The verse as a picture"
                )
            }
            .accessibilityIdentifier("shareImage")
        }
        .buttonStyle(.plain)
        .frame(width: 250)
        .padding(.vertical, 4)
    }

    private func row(_ symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(theme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(isDevanagari ? .glossDevanagari : .glossLatin)
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(.label)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}
