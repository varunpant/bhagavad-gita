//
//  Fonts.swift
//  Gita
//

import CoreText
import Foundation
import os

/// Registers the two bundled faces with the process that is drawing.
///
/// **Why registration rather than `UIAppFonts`.** The plist route needs a
/// different key on each platform — `UIAppFonts` on iOS, `ATSApplicationFontsPath`
/// on macOS, and the latter needs the files at `Contents/Resources/Fonts`,
/// which is not where a flattened iOS bundle puts them. One call that works
/// the same in both is fewer things to be wrong.
///
/// **Called once, from `GitaApp.init`.** This used to say it was called twice,
/// in two processes, and that the widget carried its own copy of the fonts —
/// which `GitaWidgetBundle` flatly contradicts, and the widget is the one
/// telling the truth. A widget cannot read the app's bundle, so using these
/// faces there would mean copying both files into the extension; instead
/// `WidgetLook` picks the system faces nearest them, and says why.
///
/// Registration is `.process` scope: nothing is installed for the user, and
/// nothing outlives the run.
enum Fonts {
    /// The two variable faces, by file name inside whichever bundle asks.
    static let files = ["Inter-Variable", "NotoSansDevanagari-Variable"]

    /// Family names, which is what `Font.custom` resolves.
    ///
    /// A variable font's named instances arrive as `Inter-Regular_SemiBold`
    /// and friends — the PostScript names, which are not worth writing out.
    /// Asking for the *family* and then a weight lets CoreText pick the
    /// instance, so the roles below stay readable.
    static let latin = "Inter"
    static let devanagari = "Noto Sans Devanagari"

    /// Whether both faces are actually available to draw with.
    ///
    /// Read after `register()`, and false only if a bundle shipped without
    /// them. Nothing branches on it today — SwiftUI substitutes silently, and
    /// this is here so that a substitution can be *noticed* in a log rather
    /// than discovered in a screenshot.
    private(set) nonisolated(unsafe) static var isRegistered = false

    /// Registers every bundled face, once.
    ///
    /// Idempotent: a second call is a no-op, and a face the process already
    /// has is not an error worth reporting — `CTFontManagerRegisterFontsForURL`
    /// says so with `kCTFontManagerErrorAlreadyRegistered`, which is a success
    /// as far as anything here is concerned.
    static func register(in bundle: Bundle = .main) {
        guard !isRegistered else { return }

        var missing: [String] = []
        for name in files {
            guard let url = bundle.url(forResource: name, withExtension: "ttf") else {
                missing.append(name)
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let code = (error?.takeRetainedValue() as Error?).map {
                    ($0 as NSError).code
                }
                // 105 is `kCTFontManagerErrorAlreadyRegistered`.
                if code != 105 { missing.append(name) }
            }
        }

        isRegistered = missing.isEmpty
        if !missing.isEmpty {
            // `os` directly rather than the app's `Logger.ui`: this file is
            // compiled into the widget too, and the extension does not carry
            // `Logger+Extensions`.
            Logger(subsystem: bundle.bundleIdentifier ?? "com.varunpant.Gita",
                   category: "fonts")
                .error("font registration failed for \(missing.joined(separator: ", "), privacy: .public)")
        }
    }
}
