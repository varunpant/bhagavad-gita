//
//  ProgressWidgetView.swift
//  GitaWidget
//

import SwiftUI
import WidgetKit

/// The three sizes of the progress widget.
///
/// Every string and every numeral follows the reading language the app shared —
/// a widget belonging to a Devanagari reader that answers in English is the same
/// jar as an English subtitle under a Sanskrit heading. See `app/CLAUDE.md`.
struct ProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: ProgressEntry

    private var theme: Theme {
        .forWidget(entry.progress?.theme, colorScheme: colorScheme)
    }

    private var isDevanagari: Bool { entry.progress?.isDevanagari ?? true }

    var body: some View {
        Group {
            if let progress = entry.progress {
                content(progress)
            } else {
                NotReadyView()
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                theme.background
                theme.wash
            }
        }
        .widgetURL(URL(string: "gita://progress"))
    }

    @ViewBuilder
    private func content(_ progress: SharedProgress) -> some View {
        switch family {
        case .accessoryCircular:
            // The lock screen tints everything it is given, so the ramp would be
            // flattened to one colour anyway — use the system's own gauge there
            // rather than a ring pretending to be coloured.
            Gauge(value: progress.completion) {
                Text(progress.versesRead.digits(devanagari: isDevanagari))
            }
            .gaugeStyle(.accessoryCircularCapacity)

        case .systemMedium:
            medium(progress)

        case .systemLarge:
            large(progress)

        default:
            small(progress)
        }
    }

    // MARK: - Small: the ring and the count

    private func small(_ progress: SharedProgress) -> some View {
        ZStack {
            BrandRing(completion: progress.completion, theme: theme, lineWidth: 11)
            counts(progress, size: 30)
        }
        .padding(4)
    }

    /// The two numbers inside the ring: what has been read, over the whole book.
    /// Stacked rather than written `327/701`, so the number that matters is the
    /// one the eye lands on.
    private func counts(_ progress: SharedProgress, size: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(progress.versesRead.digits(devanagari: isDevanagari))
                .font(isDevanagari ? .widgetDevanagari(size) : .widgetNumber(size))
                .foregroundStyle(theme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(dividedBy(progress.totalVerses))
                .font(isDevanagari ? .widgetDevanagari(size * 0.44) : .widgetSerif(size * 0.42))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
    }

    private func dividedBy(_ total: Int) -> String {
        "/ " + total.digits(devanagari: isDevanagari)
    }

    // MARK: - Medium: today against the whole

    private func medium(_ progress: SharedProgress) -> some View {
        let week = progress.recentDays(7, ending: entry.date)
        let busiest = max(1, week.map(\.count).max() ?? 1)

        return HStack(spacing: 16) {
            ZStack {
                BrandRing(completion: progress.completion, theme: theme, lineWidth: 9)
                counts(progress, size: 24)
            }
            .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 10) {
                figure(
                    value: progress.count(on: entry.date),
                    label: isDevanagari ? "आज" : "TODAY"
                )
                figure(
                    value: progress.currentStreak,
                    label: isDevanagari ? "दिन लगातार" : "DAY STREAK",
                    symbol: "flame.fill"
                )
            }

            Spacer(minLength: 0)

            // The week, unlabelled. Today against the whole is the point of this
            // size, and the last seven days are the shape of that — without them
            // the right third of a medium widget was empty. No numerals and no
            // weekday letters: at this width they would be noise, and the large
            // size is where the chart is read rather than glanced at.
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(week, id: \.date) { day in
                    DayBar(
                        fraction: Double(day.count) / Double(busiest),
                        theme: theme,
                        isToday: Calendar.current.isDate(day.date, inSameDayAs: entry.date)
                    )
                    .frame(width: 7)
                }
            }
            .frame(height: 62)
        }
        .padding(.vertical, 2)
    }

    private func figure(value: Int, label: String, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Text(value.digits(devanagari: isDevanagari))
                    .font(isDevanagari ? .widgetDevanagari(26) : .widgetNumber(26))
                    .foregroundStyle(theme.textPrimary)
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 13))
                        .foregroundStyle(Brand.ramp[2])
                }
            }
            Text(label)
                .font(isDevanagari ? .widgetDevanagari(11) : .widgetLabel)
                .tracking(isDevanagari ? 0 : 0.8)
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Large: the week, over the whole

    private func large(_ progress: SharedProgress) -> some View {
        let week = progress.recentDays(7, ending: entry.date)
        let busiest = max(1, week.map(\.count).max() ?? 1)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    BrandRing(completion: progress.completion, theme: theme, lineWidth: 8)
                    counts(progress, size: 21)
                }
                .frame(width: 88, height: 88)

                VStack(alignment: .leading, spacing: 10) {
                    figure(
                        value: week.reduce(0) { $0 + $1.count },
                        label: isDevanagari ? "इस सप्ताह" : "THIS WEEK"
                    )
                    figure(
                        value: progress.currentStreak,
                        label: isDevanagari ? "दिन लगातार" : "DAY STREAK",
                        symbol: "flame.fill"
                    )
                }
                Spacer(minLength: 0)
            }

            Rectangle().fill(theme.divider).frame(height: 1)

            chart(week, busiest: busiest)
        }
    }

    /// Seven days, oldest on the left, today lit. The busiest day sets the
    /// scale — a fixed maximum would flatten a quiet week into nothing and clip
    /// a heavy one.
    private func chart(_ week: [(date: Date, count: Int)], busiest: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(week, id: \.date) { day in
                    VStack(spacing: 6) {
                        Text(day.count == 0 ? "" : day.count.digits(devanagari: isDevanagari))
                            .font(isDevanagari ? .widgetDevanagari(11) : .widgetLabel)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)

                        DayBar(
                            fraction: Double(day.count) / Double(busiest),
                            theme: theme,
                            isToday: Calendar.current.isDate(day.date, inSameDayAs: entry.date)
                        )

                        Text(weekday(day.date))
                            .font(isDevanagari ? .widgetDevanagari(11) : .widgetLabel)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// One letter in English, one syllable in Devanagari — the weekday names in
    /// full would not fit seven across at any size.
    private func weekday(_ date: Date) -> String {
        let index = Calendar.current.component(.weekday, from: date) - 1
        let devanagari = ["र", "सो", "मं", "बु", "गु", "शु", "श"]
        let latin = ["S", "M", "T", "W", "T", "F", "S"]
        let names = isDevanagari ? devanagari : latin
        return names[max(0, min(names.count - 1, index))]
    }
}

// MARK: - Previews
//
// The widget gallery is the only other place these can be seen, and it cannot
// be reached from a build. `SharedProgress.preview` is the same sample the
// gallery uses, so what is checked here is what a first-time reader sees.

#Preview("Progress — small", as: .systemSmall) {
    ProgressWidget()
} timeline: {
    ProgressEntry(date: Date(), progress: .preview)
}

#Preview("Progress — medium", as: .systemMedium) {
    ProgressWidget()
} timeline: {
    ProgressEntry(date: Date(), progress: .preview)
}

#Preview("Progress — large", as: .systemLarge) {
    ProgressWidget()
} timeline: {
    ProgressEntry(date: Date(), progress: .preview)
}
