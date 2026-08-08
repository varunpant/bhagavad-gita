//
//  ReadingLanguage.swift
//  Gita
//

import Foundation

/// Which rendering of the verse the reader is showing.
///
/// Mirrors RigVeda's `Language`: one switch flips both the scripture and the
/// word-by-word glosses together, rather than making them independent settings
/// nobody wants to manage separately.
enum ReadingLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Devanagari shloka, Hindi word meanings.
    case sanskrit
    /// IAST transliteration, English word meanings.
    case english

    var id: String { rawValue }

    /// The glyph on the toggle — "अ" or "A", the script each mode is written in.
    var icon: String {
        switch self {
        case .sanskrit: "अ"
        case .english: "A"
        }
    }

    var accessibilityName: String {
        switch self {
        case .sanskrit: "Sanskrit with Hindi meanings"
        case .english: "Transliteration with English meanings"
        }
    }

    var toggled: ReadingLanguage {
        self == .sanskrit ? .english : .sanskrit
    }

    /// Which mode the reader opens in. Debug builds honour a launch argument so
    /// UI tests and screenshot runs can start in either mode without tapping.
    static var launchDefault: ReadingLanguage {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-startInEnglish") ? .english : .sanskrit
        #else
        .sanskrit
        #endif
    }
}
