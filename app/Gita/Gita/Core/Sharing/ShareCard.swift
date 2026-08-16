//
//  ShareCard.swift
//  Gita
//

import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The verse as a square image, for sending to someone.
///
/// A SwiftUI view rendered through `ImageRenderer` rather than drawn by hand
/// into a Core Graphics context. RigVeda does the latter in 195 lines of UIKit
/// — which is both a lot of arithmetic to get wrong and impossible to compile
/// for Mac. This way the card is laid out by the same engine as the app, in the
/// same faces, and it renders on every platform.
///
/// Always light: a share card lands in someone else's timeline, where the
/// reader's chosen theme means nothing and a dark card looks like a mistake.
struct ShareCard: View {
    let verse: Verse
    let language: ReadingLanguage

    private var isDevanagari: Bool { language.isDevanagari }

    /// 1080pt square at 1× — `ImageRenderer` is asked for 1× because the view
    /// is already sized in final pixels. Square travels best: it is what
    /// Instagram and WhatsApp show without cropping.
    static let side: CGFloat = 1080

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 44) {
                Text(verse.displayLines(for: language).joined(separator: "\n"))
                    .font(.card(devanagari: isDevanagari, size: 52))
                    .lineSpacing(isDevanagari ? 22 : 14)
                    .foregroundStyle(.black)

                if let translation = verse.translation(for: language), !translation.isEmpty {
                    Text(translation)
                        .font(.card(devanagari: isDevanagari, size: 34))
                        .lineSpacing(12)
                        .foregroundStyle(.black.opacity(0.7))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 96)

            Spacer(minLength: 0)

            footer
        }
        .frame(width: Self.side, height: Self.side)
        .background(.white)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Rectangle()
                .fill(.black.opacity(0.12))
                .frame(width: 120, height: 1)

            Text(verse.shareTitle(for: language))
                .font(.card(devanagari: isDevanagari, size: 30, medium: true))
                .foregroundStyle(.black.opacity(0.75))
        }
        .padding(.bottom, 76)
    }

}

// MARK: - Transferable

/// The verse as a shareable PNG, rendered at the moment something asks for it.
///
/// This exists because `ShareLink` needs its item up front, while the card is
/// expensive enough that rendering all 701 eagerly would be absurd. An earlier
/// attempt kept an optional `Image` in view state and showed the image row only
/// once it was filled — but the popover's content is built as it is presented,
/// and never saw the value arrive, so the row simply never appeared.
///
/// As a `Transferable` the problem disappears: the item is always available,
/// and the work happens inside the exporter, which the share sheet calls only
/// if the reader actually picks the image.
nonisolated struct VerseCard: Transferable {
    let verse: Verse
    let language: ReadingLanguage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            // `ImageRenderer` walks a SwiftUI view tree, so it is main-actor
            // work even though the export itself is not.
            try await MainActor.run {
                guard let data = ShareCard.png(verse: card.verse, language: card.language) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                return data
            }
        }
        .suggestedFileName { card in
            "gita-\(card.verse.chapter)-\(card.verse.sutra).png"
        }
    }
}

extension ShareCard {
    /// PNG bytes for the card, or nil if rendering fails.
    @MainActor
    static func png(verse: Verse, language: ReadingLanguage) -> Data? {
        let renderer = ImageRenderer(content: ShareCard(verse: verse, language: language))
        renderer.scale = 1

        #if canImport(UIKit)
        return renderer.uiImage?.pngData()
        #elseif canImport(AppKit)
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }
}
