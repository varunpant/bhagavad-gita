//
//  DeepLink.swift
//  Gita
//

import Foundation

/// Where a `gita://` URL asks the app to go.
///
/// Two things arrive this way: a widget tapped on the Home Screen, and a link
/// someone shared from the share sheet. Both land in `ReaderView.onOpenURL`,
/// where the parsing used to live inline — a closure, so the only way to test
/// it was to launch the app and open a URL, which nothing did.
///
/// It is worth testing because of what a wrong answer looks like. There is no
/// error state: a URL that does not parse simply does nothing, so a widget that
/// stops opening its verse looks like a widget that did not register the tap,
/// and a shared link that stops working looks like the recipient not having the
/// app. Both are silent, and both are reported as something else.
///
/// **On the scheme.** `gita` is not registered to anyone: custom URL schemes
/// are first-come, first-served, and if another app claims the same one iOS
/// picks between them by no documented rule. That is a known and accepted
/// trade — the alternative is a universal link, which needs the website to
/// vouch for the app, and this app deliberately does not send people to a
/// website. See `Gita-Info.plist`, which is where the scheme is declared.
///
/// `nonisolated`, like `FamousVerses` and `WelcomeSample`: parsing a URL is
/// pure, and the suite that pins it has no reason to be on the main actor.
nonisolated enum DeepLink: Equatable, Sendable {
    /// `gita://verse/2/47`
    case verse(chapter: Int, sutra: Int)
    /// `gita://progress` — the progress widget's own tap target. It opens the
    /// panel the widget summarises rather than dropping the reader somewhere
    /// unrelated to what they tapped.
    case progress

    static let scheme = "gita"

    /// Nothing for anything this app did not send: a wrong scheme, an unknown
    /// host, a missing or non-numeric component. Deliberately silent — an app
    /// that raised an error at a stray URL would be complaining about someone
    /// else's mistake, in front of the reader.
    init?(_ url: URL) {
        guard url.scheme == Self.scheme else { return nil }

        switch url.host {
        case "progress":
            self = .progress

        case "verse":
            // `pathComponents` opens with "/" for an absolute path, and a
            // custom-scheme URL may or may not have one depending on how it was
            // written. Filtering is what makes both spellings parse the same.
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count == 2,
                  let chapter = Int(parts[0]), let sutra = Int(parts[1]),
                  chapter > 0, sutra > 0
            else { return nil }
            self = .verse(chapter: chapter, sutra: sutra)

        default:
            return nil
        }
    }
}
