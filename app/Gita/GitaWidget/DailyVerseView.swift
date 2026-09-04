//
//  DailyVerseView.swift
//  GitaWidget
//

import SwiftUI
import WidgetKit

/// The day's verse.
///
/// Typeset rather than laid out: the shloka is the subject, so it gets the
/// Devanagari face and the room, and everything else — the reference, the
/// translation — is set quieter around it. The theme and the reading language
/// come from the App Group, so the widget matches the app the reader left.
struct DailyVerseView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: Entry

    /// Progress is read here only for the two things it carries about the
    /// reader rather than about progress: which theme and which script. Absent
    /// before the first launch, when the defaults are the app's own.
    private var shared: SharedProgress? { SharedProgressStore.read() }

    private var theme: Theme {
        .forWidget(shared?.theme, colorScheme: colorScheme)
    }

    private var isDevanagari: Bool { shared?.isDevanagari ?? true }

    var body: some View {
        Group {
            if let verse = entry.verse {
                content(verse)
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
    }

    @ViewBuilder
    private func content(_ verse: WidgetVerse) -> some View {
        switch family {
        case .accessoryRectangular:
            // The lock screen gives no colour and very little room, so this one
            // stays plain on purpose.
            VStack(alignment: .leading, spacing: 2) {
                Text(verse.reference)
                    .font(.caption2.weight(.semibold))
                Text(firstLine(of: verse.sanskrit))
                    .font(.caption2)
                    .lineLimit(2)
            }
            .widgetURL(url(for: verse))

        case .systemMedium:
            VStack(alignment: .leading, spacing: 9) {
                header(verse)

                Text(verse.sanskrit)
                    .font(.widgetDevanagari(17))
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                if let english = verse.english {
                    Text(english)
                        .font(.widgetLatin(12))
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(1)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(url(for: verse))

        default:
            VStack(alignment: .leading, spacing: 8) {
                header(verse)

                Text(firstLine(of: verse.sanskrit))
                    .font(.widgetDevanagari(16))
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(2)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(url(for: verse))
        }
    }

    /// The reference on a saffron rule: the one piece of brand on a face that is
    /// otherwise all text, and enough to make the widget recognisable at a
    /// glance from across a home screen.
    private func header(_ verse: WidgetVerse) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(LinearGradient(colors: Brand.ramp, startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 12)

            Text(reference(verse))
                .font(isDevanagari ? .widgetDevanagari(12) : .widgetLabel)
                .tracking(isDevanagari ? 0 : 0.8)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func reference(_ verse: WidgetVerse) -> String {
        verse.chapter.digits(devanagari: isDevanagari)
            + "." + verse.sutra.digits(devanagari: isDevanagari)
    }

    /// One line is all a small widget has room for, and the shloka is stored
    /// line by line, so take the first rather than truncating mid-word.
    private func firstLine(of text: String) -> String {
        text.split(separator: "\n").first.map(String.init) ?? text
    }

    private func url(for verse: WidgetVerse) -> URL? {
        URL(string: "gita://verse/\(verse.chapter)/\(verse.sutra)")
    }
}

/// Shown only before the app has ever been opened, when there is nothing in the
/// shared container yet.
///
/// Quiet and instructive rather than an error: nothing has gone wrong, the app
/// simply has not run once. One tap fixes it, and the widget fills itself in.
struct NotReadyView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "book.closed")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Open Gita once")
                .font(.footnote.weight(.medium))
            Text("to show a verse here")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "gita://open"))
    }
}
