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
    /// Cheap to call on every launch: the common case reads two values from
    /// shared defaults and checks the file is still there.
    @discardableResult
    static func exportIfNeeded(_ verses: [Verse], contentVersion: String) -> Bool {
        guard let fileURL else {
            logger.notice("No App Group container; widgets will have no data")
            return false
        }
        // A stamp, not the payload. This used to `read()` — a full 680 KB file
        // read and a decode of 701 structs — on every launch, purely to compare
        // a version string and a count.
        if let last = lastExported, last.version == contentVersion, last.count == verses.count,
           FileManager.default.fileExists(atPath: fileURL.path) {
            return false
        }

        let payload = Payload(
            contentVersion: contentVersion,
            verses: verses.map {
                WidgetVerse(
                    chapter: $0.chapter,
                    sutra: $0.sutra,
                    sanskrit: $0.sanskrit,
                    english: $0.englishTranslation
                )
            }
        )

        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
            lastExported = (contentVersion, payload.verses.count)
            logger.info("Exported \(payload.verses.count) verses for widgets (\(data.count / 1024) KB)")
            return true
        } catch {
            logger.error("Export failed: \(error.localizedDescription)")
            return false
        }
    }
}
