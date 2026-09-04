//
//  Theme.swift
//  Gita
//

import SwiftUI

/// The four reading themes from specs.md section 9.1.
///
/// Sepia is a real theme, not a tint on light mode, so the palette cannot ride
/// on `ColorScheme` alone — it is resolved once and injected through the
/// environment, and every colour in the app is read from it by role.
enum Theme: String, Sendable {
    case light
    case sepia
    case dark


    static func resolved(for colorScheme: ColorScheme) -> Theme {
        colorScheme == .dark ? .dark : .light
    }

    // MARK: - Tokens
    //
    // Light and dark are plain: white or black ground, primary/secondary text,
    // and no tint anywhere. Sepia is the only theme that colours anything —
    // choosing System should look like a system app, not like a warm one.

    var background: Color {
        switch self {
        case .light: .white
        case .sepia: Color(hex: 0xF3E9D6)
        case .dark: .black
        }
    }

    var surface: Color {
        switch self {
        case .light: .white
        case .sepia: Color(hex: 0xFBF3E4)
        case .dark: Color(hex: 0x1C1C1E)
        }
    }

    /// Black on light, white on dark — `.primary` follows the color scheme,
    /// which `preferredColorScheme` has already pinned to match the theme.
    var textPrimary: Color {
        switch self {
        case .light, .dark: .primary
        case .sepia: Color(hex: 0x35291A)
        }
    }

    var textSecondary: Color {
        switch self {
        case .light, .dark: .secondary
        case .sepia: Color(hex: 0x6E5C43)
        }
    }

    /// The colour of controls. Monochrome outside Sepia: a "System" theme that
    /// tinted everything saffron was the whole problem.
    var accent: Color {
        switch self {
        case .light, .dark: .primary
        case .sepia: Color(hex: 0xB4571A)
        }
    }

    /// The colour of a thing that is on, or that you are in: a switch turned
    /// on, the chapter and the verse the reader is currently at.
    ///
    /// The one place brand colour is allowed past the rail. `accent` is
    /// deliberately monochrome outside Sepia — a "System" theme that tinted
    /// every control saffron was the original mistake — but *state* is not a
    /// control, and a black disc marking where you are reads as a hole in the
    /// page rather than as a place.
    ///
    /// The yellow end of the ramp in Light; the deep orange at its foot in
    /// Dark, where that yellow glares against black. Sepia keeps its own
    /// accent: it is the one theme that already colours its controls, and a
    /// second colour beside that reads as a mistake.
    var selectionTint: Color {
        switch self {
        case .light: Brand.ramp[0]
        case .dark: Brand.ramp[3]
        case .sepia: accent
        }
    }

    /// `selectionTint` with a sheen, for the one selected thing on a panel.
    ///
    /// Built *around* each theme's own tint rather than from the whole ramp,
    /// so `onSelection` stays the right ink. Sweeping yellow to vermillion in
    /// every theme would look like the brand but break that pairing: dark ink
    /// is correct on Light's yellow and invisible on the vermillion the same
    /// sweep would end in.
    ///
    /// Sepia keeps a single hue and shifts only in weight. It is the one theme
    /// that already colours its controls, and a second colour beside that reads
    /// as a mistake, which is the rule `selectionTint` above follows too.
    var selectionGradient: LinearGradient {
        let stops: [Color] = switch self {
        case .light: [Brand.ramp[0], Brand.ramp[1]]
        case .dark:  [Brand.ramp[2], Brand.ramp[3]]
        case .sepia: [accent, accent.opacity(0.78)]
        }
        return LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The switch track, which is the same idea with a different constraint.
    ///
    /// A track carries no text, only a white knob, so it is free to sweep the
    /// ramp properly where `selectionGradient` cannot: yellow into orange in
    /// Light, and the same sweep reversed in Dark, so the deep end meets the
    /// eye first against a dark ground. Sepia shifts weight rather than hue,
    /// for the reason given above.
    ///
    /// Two gradients rather than one because the constraints genuinely differ.
    /// Reversing this one under a numeral would end Dark's sweep in yellow,
    /// and `onSelection` there is white.
    var switchGradient: LinearGradient {
        let stops: [Color] = switch self {
        case .light: [Brand.ramp[0], Brand.ramp[2]]
        case .dark:  [Brand.ramp[2], Brand.ramp[0]]
        case .sepia: [accent.opacity(0.78), accent]
        }
        return LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing)
    }

    /// The ink to draw *on* `selectionTint`.
    ///
    /// Not `background`, which is what a monochrome accent wanted: white on the
    /// ramp's yellow is barely there. Dark on the yellow, white on the deep
    /// orange, and Sepia unchanged.
    var onSelection: Color {
        switch self {
        case .light: Color(hex: 0x3A2306)
        case .dark: .white
        case .sepia: background
        }
    }

    var divider: Color {
        switch self {
        case .light, .dark: Color.secondary.opacity(0.25)
        case .sepia: Color(hex: 0x35291A).opacity(0.15)
        }
    }

    /// What to call it on screen. `ThemePreference` names the *choice*,
    /// including "System"; this names the palette that choice resolved to.
    func displayName(isDevanagari: Bool) -> String {
        switch self {
        case .light: isDevanagari ? "प्रकाश" : "Light"
        case .sepia: isDevanagari ? "सेपिया" : "Sepia"
        case .dark: isDevanagari ? "अंधकार" : "Dark"
        }
    }

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }
}

extension EnvironmentValues {
    @Entry var theme: Theme = .light
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
