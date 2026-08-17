//
//  PanelHeader.swift
//  Gita
//

import SwiftUI

/// The title strip at the top of a rail panel.
///
/// Contents, Bookmarks and Progress each had their own copy of this: the same
/// title, the same pair of fonts, the same letter-spacing that applies only to
/// the Latin form, and the same hairline underneath. Three copies of a rule
/// that has to agree across all three panels, or the app looks assembled from
/// parts.
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

            Spacer(minLength: 0)

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.divider).frame(height: 1)
        }
    }
}

extension PanelHeader where Trailing == EmptyView {
    init(sanskrit: String, english: String, isDevanagari: Bool) {
        self.init(sanskrit: sanskrit, english: english, isDevanagari: isDevanagari) { EmptyView() }
    }
}
