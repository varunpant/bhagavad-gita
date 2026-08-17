//
//  BadgeGrid.swift
//  Gita
//

import SwiftUI

/// Badges, earned ones solid and the rest dimmed.
///
/// Locked badges are shown rather than hidden: the point of a badge is to be
/// something to aim at, and one you cannot see is not one you are aiming at.
/// They are dimmed, not blanked, for the same reason — a row of question marks
/// tells the reader nothing about what the app wants from them.
///
/// A symbol and a name is as much as a cell this size can carry, and a name is
/// not an explanation — so every cell is a button that opens
/// `BadgeDetailView` with what earns it and how far off it is.
struct BadgeGrid: View {
    let badges: [Badge]
    let earned: Set<String>
    let isDevanagari: Bool
    let onSelect: (Badge) -> Void

    @Environment(\.theme) private var theme
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// Two across on a phone, four on an iPad or a Mac — the same rule the
    /// contents follow, from `PanelColumns`.
    ///
    /// It used to be `.adaptive(minimum: 76)`, which fitted three or four narrow
    /// columns on a phone and hyphenated the English names into rubble: "The
    /// Despond-ency of Ar…", and worse at large text sizes. The names are the
    /// goals, so the column count follows the longest of them rather than the
    /// smallest cell that will fit.
    private var columns: [GridItem] {
        #if os(iOS)
        let count = PanelColumns.badges.count(for: sizeClass)
        #else
        let count = PanelColumns.badges.count
        #endif
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(badges) { badge in
                cell(badge, isEarned: earned.contains(badge.id))
            }
        }
        .padding(.horizontal, 16)
    }

    private func cell(_ badge: Badge, isEarned: Bool) -> some View {
        Button {
            Haptics.selection()
            onSelect(badge)
        } label: {
            face(badge, isEarned: isEarned)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("badge-\(badge.id)")
        .accessibilityLabel(
            "\(badge.titleEn). \(badge.detailEn). \(isEarned ? "Earned" : "Not yet earned")"
        )
        .accessibilityHint("Shows what this goal is and how far along you are")
    }

    private func face(_ badge: Badge, isEarned: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isEarned ? theme.accent.opacity(0.10) : theme.divider.opacity(0.5))
                    .frame(width: 44, height: 44)

                Image(systemName: badge.symbol)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(isEarned ? theme.accent : theme.textSecondary)
            }

            Text(badge.title(isDevanagari: isDevanagari))
                .font(isDevanagari ? .labelDevanagari : .label)
                .foregroundStyle(isEarned ? theme.textPrimary : theme.textSecondary)
                .multilineTextAlignment(.center)
                // Three lines: at three columns "Liberation through
                // Renunciation" still ellipsizes at two, and a badge whose name
                // you cannot read is not a goal. Reserved, so a grid of
                // one-word Devanagari titles is the same height as a grid of
                // English phrases and switching language does not resize it.
                .lineLimit(3, reservesSpace: true)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        // Dimming the whole cell rather than each part keeps one number in
        // charge of how "locked" reads.
        .opacity(isEarned ? 1 : 0.45)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
    }
}
