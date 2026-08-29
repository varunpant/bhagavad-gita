//
//  BadgeDetailView.swift
//  Gita
//

import SwiftUI

/// What one goal is, and how it is reached.
///
/// The grid can only show a symbol and a name, and a name like "Steady in
/// Wisdom" says nothing about what earns it. This is the rest of the answer:
/// what has to happen, how far along it is, and — for a locked one — what is
/// still left. It is deliberately one screenful with no controls but Done; a
/// goal you have to scroll to understand is not explained.
///
/// Everything on it follows the reading language, numerals included — see the
/// language rules in `app/CLAUDE.md`.
struct BadgeDetailView: View {
    let badge: Badge
    let snapshot: ProgressSnapshot
    let isEarned: Bool
    let isDevanagari: Bool

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var standing: Badge.Standing { badge.standing(in: snapshot) }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 22) {
                    medal
                    titles
                    requirement
                    if standing.isCountable { progress }
                    outcome
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .background(theme.background)
        .tint(theme.accent)
    }

    // MARK: - Header

    private var header: some View {
        PanelHeader(sanskrit: "लक्ष्य", english: "GOAL", isDevanagari: isDevanagari) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .regular))
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .accessibilityIdentifier("badgeDetailClose")
            .accessibilityLabel("Close goal")
        }
    }

    // MARK: - The badge itself

    private var medal: some View {
        ZStack {
            Circle()
                .fill(isEarned ? theme.selectionTint.opacity(0.12) : theme.divider.opacity(0.5))
                .frame(width: 96, height: 96)

            Image(systemName: badge.symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(isEarned ? theme.selectionTint : theme.textSecondary)
        }
        .opacity(isEarned ? 1 : 0.6)
        .padding(.top, 12)
        .accessibilityHidden(true)
    }

    private var titles: some View {
        VStack(spacing: 8) {
            Text(badge.title(isDevanagari: isDevanagari))
                .font(isDevanagari ? .shloka : .shlokaLatin)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(badge.family.title(isDevanagari: isDevanagari))
                .font(isDevanagari ? .labelDevanagari : .label)
                .tracking(isDevanagari ? 0 : 1.2)
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - How it is earned

    /// The catalogue's own sentence — "Read 250 verses", "Finish chapter 3" —
    /// which is the whole of the "how".
    private var requirement: some View {
        Text(badge.detail(isDevanagari: isDevanagari))
            .font(isDevanagari ? .proseDevanagari : .proseLatin)
            .foregroundStyle(theme.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A bar and a count. Only for goals that count towards something — a
    /// landmark verse has no halfway.
    private var progress: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.divider)
                    Capsule()
                        .fill(LinearGradient(colors: Brand.ramp,
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * standing.fraction)
                }
            }
            .frame(height: 6)

            Text(countLine)
                .font(isDevanagari ? .labelDevanagari : .label)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var countLine: String {
        let current = standing.current.digits(devanagari: isDevanagari)
        let target = standing.target.digits(devanagari: isDevanagari)
        return isDevanagari ? "\(target) में से \(current)" : "\(current) of \(target)"
    }

    // MARK: - Where that leaves the reader

    /// Earned, or what is still to do. The remainder is spelled out rather than
    /// left to be worked out from the bar: "67 verses to go" is the sentence a
    /// reader is actually asking for.
    private var outcome: some View {
        HStack(spacing: 8) {
            Image(systemName: isEarned ? "checkmark.seal.fill" : "hourglass")
                .font(.system(size: 14))
            Text(outcomeLine)
                .font(isDevanagari ? .glossDevanagari : .glossLatin)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(isEarned ? theme.selectionTint : theme.textSecondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule().fill(isEarned ? theme.selectionTint.opacity(0.14) : theme.divider.opacity(0.45))
        }
        .accessibilityElement(children: .combine)
    }

    private var outcomeLine: String {
        if isEarned {
            return isDevanagari ? "यह लक्ष्य पूर्ण हुआ" : "Earned"
        }
        guard standing.isCountable else {
            // A landmark: there is nothing to count, only somewhere to get to.
            return isDevanagari ? "अभी तक नहीं पहुँचे" : "Not reached yet"
        }

        let remaining = max(0, standing.target - standing.current)
        let count = remaining.digits(devanagari: isDevanagari)
        switch badge.requirement {
        case .versesRead:
            return isDevanagari ? "\(count) श्लोक शेष" : "\(count) verses to go"
        case .chapterComplete:
            return isDevanagari ? "इस अध्याय के \(count) श्लोक शेष"
                                : "\(count) verses left in this chapter"
        case .currentStreak:
            return isDevanagari ? "\(count) दिन और लगातार" : "\(count) more days in a row"
        case .verseReached:
            return isDevanagari ? "अभी तक नहीं पहुँचे" : "Not reached yet"
        }
    }
}
