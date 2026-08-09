//
//  DailyVerseView.swift
//  GitaWidget
//

import SwiftUI
import WidgetKit

struct DailyVerseView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        if let verse = entry.verse {
            content(verse)
        } else {
            NotReadyView()
        }
    }

    @ViewBuilder
    private func content(_ verse: WidgetVerse) -> some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(verse.reference)
                    .font(.caption2.weight(.semibold))
                Text(firstLine(of: verse.sanskrit))
                    .font(.caption2)
                    .lineLimit(2)
            }
            .widgetURL(url(for: verse))

        case .systemMedium:
            VStack(alignment: .leading, spacing: 8) {
                header(verse)
                Text(verse.sanskrit)
                    .font(.system(size: 15))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let english = verse.english {
                    Text(english)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(url(for: verse))

        default:
            VStack(alignment: .leading, spacing: 6) {
                header(verse)
                Text(firstLine(of: verse.sanskrit))
                    .font(.system(size: 14))
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(url(for: verse))
        }
    }

    private func header(_ verse: WidgetVerse) -> some View {
        Text(verse.reference)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
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
