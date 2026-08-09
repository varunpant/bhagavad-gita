//
//  SharedVerses+Export.swift
//  Gita
//

import Foundation
import OSLog

/// Writing the shared corpus is the app's job and needs `Verse`; reading it is
/// the widget's and must not. Splitting them keeps GRDB out of the extension.
nonisolated extension SharedVerses {
    /// Export unless an export of this content version is already there.
    ///
    /// Cheap to call on every launch: the common case is one file-read of a
    /// version string.
    @discardableResult
    static func exportIfNeeded(_ verses: [Verse], contentVersion: String) -> Bool {
        guard let fileURL else {
            logger.notice("No App Group container; widgets will have no data")
            return false
        }
        if let existing = read(), existing.contentVersion == contentVersion,
           existing.verses.count == verses.count {
            return false
        }

        let payload = Payload(
            contentVersion: contentVersion,
            verses: verses.map {
                WidgetVerse(
                    chapter: $0.chapter,
                    sutra: $0.sutra,
                    sanskrit: $0.sanskrit,
                    transliteration: $0.transliteration,
                    english: $0.englishTranslation,
                    hindi: $0.hindiTranslation
                )
            }
        )

        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
            logger.info("Exported \(payload.verses.count) verses for widgets (\(data.count / 1024) KB)")
            return true
        } catch {
            logger.error("Export failed: \(error.localizedDescription)")
            return false
        }
    }
}
