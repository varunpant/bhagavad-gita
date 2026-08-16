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
struct BadgeGrid: View {
    let badges: [Badge]
    let earned: Set<String>
    let isDevanagari: Bool

    @Environment(\.theme) private var theme

    // 76 rather than 92: at the panel's width the larger minimum fits only two
    // columns, which turns 35 badges into a long thin scroll.
    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(badges) { badge in
                cell(badge, isEarned: earned.contains(badge.id))
            }
        }
        .padding(.horizontal, 16)
    }

    private func cell(_ badge: Badge, isEarned: Bool) -> some View {
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
                .font(.label)
                .foregroundStyle(isEarned ? theme.textPrimary : theme.textSecondary)
                .multilineTextAlignment(.center)
                // Three lines: at three columns "Liberation through
                // Renunciation" still ellipsizes at two, and a badge whose name
                // you cannot read is not a goal.
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        // Dimming the whole cell rather than each part keeps one number in
        // charge of how "locked" reads.
        .opacity(isEarned ? 1 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(badge.titleEn). \(badge.detailEn). \(isEarned ? "Earned" : "Not yet earned")"
        )
    }
}
