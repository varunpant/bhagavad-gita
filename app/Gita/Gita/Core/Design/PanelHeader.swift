//
//  PanelHeader.swift
//  Gita
//

import SwiftUI

/// The title strip at the top of a rail panel, and the way out of it.
///
/// Contents, Bookmarks and Progress each had their own copy of this: the same
/// title, the same pair of fonts, the same letter-spacing that applies only to
/// the Latin form, and the same hairline underneath. Three copies of a rule
/// that has to agree across all three panels, or the app looks assembled from
/// parts.
///
/// The close control lives here too, trailing, at one size for every panel. It
/// used to be the rail's own icon turning into a cross while its panel was
/// open: the way out was then 72pt away on the far edge of the screen, in a
/// column of identical glyphs, and it changed shape under the finger that had
/// just opened it. A panel closes from its own top right corner.
///
/// The title takes both languages rather than a resolved string, so the font
/// and the tracking can never disagree with the script — see the language
/// rules in `app/CLAUDE.md`.
///
/// Lives in `Core/Design` beside `ProgressBar` rather than in a folder of its
/// own: both are shared by more than one feature, and both are design rules
/// made concrete rather than anything a feature owns.
struct PanelHeader<Trailing: View>: View {
    let sanskrit: String
    let english: String
    let isDevanagari: Bool
    /// What VoiceOver calls the way out — "Close contents", "Close progress".
    var closeLabel: String?
    var onClose: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Text(isDevanagari ? sanskrit : english)
                .font(isDevanagari ? .labelDevanagari : .label)
                // Letter-spacing suits small-caps Latin and damages Devanagari,
                // which is already spaced by its own headline.
                .tracking(isDevanagari ? 0 : 1.2)
                .foregroundStyle(theme.textSecondary)
                // A panel title never wraps. It is one short word, and a
                // trailing view that asks for room should lose that argument
                // rather than win it — "CHAPTERS" broken into "CHA / PTER / S"
                // to make space for a key is not a trade anyone would choose.
                .lineLimit(1)
                .fixedSize()

            Spacer(minLength: 0)

            trailing

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .regular))
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
                .accessibilityIdentifier("panelClose")
                .accessibilityLabel(closeLabel ?? "Close")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.divider).frame(height: 1)
        }
    }
}

extension PanelHeader where Trailing == EmptyView {
    init(
        sanskrit: String,
        english: String,
        isDevanagari: Bool,
        closeLabel: String? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.init(
            sanskrit: sanskrit, english: english, isDevanagari: isDevanagari,
            closeLabel: closeLabel, onClose: onClose
        ) { EmptyView() }
    }
}
