//
//  WidgetLook.swift
//  GitaWidget
//

import SwiftUI
import WidgetKit

/// How a widget picks its colours and its type.
///
/// The app's `Theme` and `Brand` are compiled into the extension rather than
/// copied into it, so a widget is the same four themes and the same saffron as
/// the app — change the ramp once and the icon, the splash and the widgets all
/// move together.
///
/// Theme is *chosen* in the app, so it arrives through the App Group like
/// everything else. When the reader has not pinned one, the widget falls back to
/// the system appearance, which is what "System" means everywhere else.
extension Theme {
    static func forWidget(_ preference: String?, colorScheme: ColorScheme) -> Theme {
        switch preference {
        case "light": .light
        case "sepia": .sepia
        case "dark": .dark
        default: resolved(for: colorScheme)
        }
    }
}

/// Widget type, which is not reading type.
///
/// `Font+Roles` is sized for a page held at reading distance; a widget is
/// glanced at from across a desk, so it wants its own scale.
///
/// **These are system faces, and the app's are not.** The app reads in Inter
/// and Noto Sans Devanagari, both bundled. A widget draws in its own process
/// and cannot read the app's bundle, so matching it exactly would mean a
/// second copy of both files — 1.5 MB of an extension whose whole job is to
/// show one verse. The near neighbours cost nothing and are already on every
/// device: SF Pro is the face Inter was drawn in the lineage of, and Kohinoor
/// is the contemporary Devanagari sans that sits closest to Noto's.
///
/// The consequence is worth naming: the widget is *deliberately* a shade off
/// the app. At widget sizes, glanced at, that is a trade worth making — but if
/// the two are ever put side by side in a screenshot, they will not be the
/// same typeface, and that is not a bug.
extension Font {
    static func widgetNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .light)
    }

    /// Kohinoor ships with both iOS and macOS; if it is ever absent SwiftUI
    /// falls back to the system Devanagari face rather than failing.
    static func widgetDevanagari(_ size: CGFloat) -> Font {
        .custom("KohinoorDevanagari-Light", size: size)
    }

    static func widgetLatin(_ size: CGFloat) -> Font {
        .system(size: size)
    }

    /// Section labels: small, spaced, upper case. The one place the widget does
    /// not follow the reading language in *face*, because Devanagari has no
    /// upper case — the Devanagari label uses Kohinoor at the same size instead.
    static let widgetLabel = Font.system(size: 10, weight: .semibold)
}
