//
//  ShareCard.swift
//  Gita
//

import SwiftUI

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

    private var isDevanagari: Bool { language == .sanskrit }

    /// 1080pt square at 1× — `ImageRenderer` is asked for 1× because the view
    /// is already sized in final pixels. Square travels best: it is what
    /// Instagram and WhatsApp show without cropping.
    static let side: CGFloat = 1080

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 44) {
                Text(verse.displayLines(for: language).joined(separator: "\n"))
                    .font(.custom(isDevanagari ? "KohinoorDevanagari-Light" : "Georgia", size: 52))
                    .lineSpacing(isDevanagari ? 22 : 14)
                    .foregroundStyle(.black)

                if let translation = verse.translation(for: language), !translation.isEmpty {
                    Text(translation)
                        .font(.custom(isDevanagari ? "KohinoorDevanagari-Light" : "Georgia", size: 34))
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

            Text(reference)
                .font(.custom(isDevanagari ? "KohinoorDevanagari-Medium" : "Georgia", size: 30))
                .foregroundStyle(.black.opacity(0.75))

            Text(verbatim: "bhagwadgita.info")
                .font(.system(size: 22, weight: .light))
                .tracking(1.5)
                .foregroundStyle(.black.opacity(0.35))
        }
        .padding(.bottom, 76)
    }

    private var reference: String {
        isDevanagari
            ? "श्रीमद्भगवद्गीता \(verse.chapter.devanagariDigits).\(verse.sutra.devanagariDigits)"
            : "Bhagavad Gita \(verse.chapter).\(verse.sutra)"
    }
}

// MARK: - Rendering

extension ShareCard {
    /// Renders the card to an `Image` ready for `ShareLink`.
    ///
    /// `@MainActor` because `ImageRenderer` is: it walks a SwiftUI view tree.
    /// It is fast enough at this size to run inline — a few milliseconds — so
    /// there is no loading state, unlike RigVeda's "Generating image…".
    @MainActor
    static func render(verse: Verse, language: ReadingLanguage) -> Image? {
        let renderer = ImageRenderer(content: ShareCard(verse: verse, language: language))
        renderer.scale = 1     // the view is already sized in final pixels

        guard let cgImage = renderer.cgImage else { return nil }
        return Image(decorative: cgImage, scale: 1)
    }
}

