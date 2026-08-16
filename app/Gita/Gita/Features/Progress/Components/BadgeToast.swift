//
//  BadgeToast.swift
//  Gita
//

import SwiftUI

/// A badge just earned, announced for a few seconds and then gone.
///
/// Sized and placed to be noticed and ignored: it sits under the status bar,
/// never covers the shloka, and needs no dismissing. Anything more — a sheet, a
/// card with a button — would interrupt the reading it is rewarding.
struct BadgeToast: View {
    let badge: Badge

    @Environment(Settings.self) private var settings
    @Environment(\.theme) private var theme

    private var isDevanagari: Bool { settings.language == .sanskrit }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: badge.symbol)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(badge.title(isDevanagari: isDevanagari))
                    .font(isDevanagari ? .glossDevanagari : .glossLatin)
                    .foregroundStyle(theme.textPrimary)
                Text(badge.detail(isDevanagari: isDevanagari))
                    .font(.label)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surface)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 420)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Badge earned: \(badge.titleEn). \(badge.detailEn)")
    }
}
