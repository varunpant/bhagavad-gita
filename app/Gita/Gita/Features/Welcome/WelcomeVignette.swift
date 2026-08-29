//
//  WelcomeVignette.swift
//  Gita
//

import SwiftUI

/// A glimpse of the real screen a welcome page is talking about.
///
/// Not a screenshot. Every one of these is the app's own views drawn small: the
/// reader's fonts and its shloka, the search band, `CompletionRing`,
/// `ProgressBar`, `ShareCard` itself. A bundled screenshot would be a
/// photograph of whatever the app looked like on the day it was taken, in one
/// script and one theme; this follows the reader's script and theme because it
/// *is* the app, and it cannot go stale.
///
/// Framed the way a store listing frames a screen — a card with a hairline
/// border, and the content running off the bottom under a fade rather than
/// stopping. A page cut cleanly in half looks broken; a page fading out reads
/// as one that carries on.
struct WelcomeVignette<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            // Laid out at something like a real page's width and then shrunk,
            // not laid out at card width: at 268pt every shloka line ended in
            // an ellipsis, which is the one thing a glimpse of the app must not
            // show.
            .frame(width: 340, alignment: .top)
            // Natural height first, clip second. The card is 236pt tall, and a
            // `Text` offered 236pt of height squeezes itself into fewer lines
            // and truncates — so every shloka line ended in an ellipsis even
            // though the width was ample.
            .fixedSize(horizontal: false, vertical: true)
            .scaleEffect(0.78, anchor: .top)
            .frame(width: 266, alignment: .top)
            .frame(height: 236, alignment: .top)
            .clipped()
            // The last fifth dissolves, so nothing ends on a cut edge.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .padding(.top, 18)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.55), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            }
            .accessibilityHidden(true)
    }
}

/// The six of them, each built from what its page is about.
///
/// Everything here reads the corpus rather than inventing text — 2.47 is the
/// verse the whole Gita is quoted for, and the search rows are verses that
/// query really returns.
struct WelcomeVignettes {
    let verse: Verse?
    let language: ReadingLanguage
    let theme: Theme

    private var isDevanagari: Bool { language.isDevanagari }

    @ViewBuilder
    var scripture: some View {
        VStack(spacing: 12) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(isDevanagari ? .shloka : .shlokaLatin)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
            }

            Text(isDevanagari ? "अनुवाद" : "TRANSLATION")
                .font(isDevanagari ? .labelDevanagari : .label)
                .tracking(isDevanagari ? 0 : 1.2)
                .foregroundStyle(theme.textSecondary)
                .padding(.top, 4)

            Text(translation)
                .font(isDevanagari ? .proseDevanagari : .proseLatin)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// The reader, chrome and all — the header is half the point of a page
    /// about turning pages.
    @ViewBuilder
    var reading: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "line.3.horizontal")
                Spacer()
                Text(reference)
                    .font(isDevanagari ? .labelDevanagari : .label)
                Spacer()
                Image(systemName: "bookmark")
            }
            .font(.system(size: 12))
            .foregroundStyle(theme.textSecondary)

            Rectangle().fill(theme.divider).frame(height: 1)

            scripture
        }
    }

    /// The three themes, each showing the same line — the only honest way to
    /// show a theme is in it.
    @ViewBuilder
    var appearance: some View {
        VStack(spacing: 10) {
            ForEach([Theme.light, .sepia, .dark], id: \.self) { swatch in
                HStack(spacing: 10) {
                    Text(lines.first ?? "")
                        .font(isDevanagari ? .glossDevanagari : .glossLatin)
                        .foregroundStyle(swatch.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(swatch.background)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(swatch.divider, lineWidth: 1)
                        }
                }
                // `textPrimary` is `.primary` outside Sepia, which follows the
                // environment — so the Dark swatch drew black on black inside a
                // welcome pinned to Light. A theme has to be shown in its own
                // colour scheme.
                .environment(\.colorScheme, swatch.colorScheme)
            }
        }
    }

    /// The search band, in the brand, over the rows that query returns.
    @ViewBuilder
    func finding(_ hits: [Verse]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(verbatim: "karma")
                    .font(.system(size: 18, design: .serif).italic())
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Brand.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(hits, id: \.id) { hit in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hit.reference)
                            .font(.label)
                            .foregroundStyle(theme.textSecondary)
                        Text(hit.englishTranslation ?? hit.sanskrit)
                            .font(.glossLatin)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        }
    }

    /// The share card itself, drawn at its own size and shrunk — the very view
    /// the reader will send to someone.
    @ViewBuilder
    var keeping: some View {
        if let verse {
            ShareCard(verse: verse, language: language)
                .frame(width: ShareCard.side, height: ShareCard.side)
                .scaleEffect(236 / ShareCard.side)
                .frame(width: 236, height: 236)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.divider, lineWidth: 1)
                }
        }
    }

    /// The real ring and the real bars, against a plausible reading.
    @ViewBuilder
    func progress(_ chapters: [Chapter], snapshot: ProgressSnapshot) -> some View {
        VStack(spacing: 10) {
            CompletionRing(
                completion: snapshot.completion,
                versesRead: snapshot.versesRead,
                totalVerses: snapshot.totalVerses,
                isDevanagari: isDevanagari
            )
            .scaleEffect(0.78)
            .frame(height: 150)

            ForEach(chapters.prefix(2)) { chapter in
                VStack(alignment: .leading, spacing: 5) {
                    Text(isDevanagari ? chapter.nameSa : chapter.nameEn)
                        .font(isDevanagari ? .labelDevanagari : .label)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    ProgressBar(fraction: snapshot.completion(ofChapter: chapter.id))
                }
            }
        }
    }

    private var lines: [String] {
        guard let verse else { return [] }
        return Array(verse.displayLines(for: language).prefix(2))
    }

    private var translation: String {
        guard let verse else { return "" }
        return verse.translation(for: language) ?? ""
    }

    private var reference: String {
        guard let verse else { return "" }
        return isDevanagari
            ? "अध्याय \(verse.chapter.devanagariDigits) · श्लोक \(verse.sutra.devanagariDigits)"
            : "Chapter \(verse.chapter) · Verse \(verse.sutra)"
    }
}
